`timescale 1ns / 1ps

// Observa IF antes y después de acciones locales, sin implementar el registro IF/ID.
module if_stage_tb #(
    parameter system_pkg::memory_capacity_t IMEM_CAPACITY_BYTES = 64'd0
);
  import system_pkg::*;

  localparam int unsigned     WORD_INDEX_WIDTH = word_index_width(IMEM_CAPACITY_BYTES);
  localparam int unsigned     IMAGE_SIZE_WIDTH = capacity_inclusive_width(IMEM_CAPACITY_BYTES);
  localparam longint unsigned INDEX_MAX        = (64'd1 << WORD_INDEX_WIDTH) - 64'd1;
  localparam longint unsigned IMAGE_SIZE_MAX   = (64'd1 << IMAGE_SIZE_WIDTH) - 64'd1;
  tp3_case_data data ();
  logic                          clk = 1'b0;
  logic                          reset = 1'b0;
  logic                          prepare_init = 1'b0;
  logic                          act_normal = 1'b0;
  logic                          act_redirect = 1'b0;
  word_t                         redirect_target = '0;
  logic   [IMAGE_SIZE_WIDTH-1:0] loaded_image_size_bytes = '0;
  logic   [WORD_INDEX_WIDTH-1:0] imem_write_index = '0;
  word_t                         imem_write_data = '0;
  logic                          imem_write_enable = 1'b0;
  if_id_t                        ifid_input;
  word_t                         debug_pc;

  if_stage #(
      .IMEM_CAPACITY_BYTES(IMEM_CAPACITY_BYTES)
  ) dut (
      .clk                    (clk),
      .reset                  (reset),
      .prepare_init           (prepare_init),
      .act_normal             (act_normal),
      .act_redirect           (act_redirect),
      .redirect_target        (redirect_target),
      .loaded_image_size_bytes(loaded_image_size_bytes),
      .imem_write_index       (imem_write_index),
      .imem_write_data        (imem_write_data),
      .imem_write_enable      (imem_write_enable),
      .ifid_input             (ifid_input),
      .debug_pc               (debug_pc)
  );

  // Rechaza truncamientos antes de aplicar las entradas del catálogo.
  function automatic longint unsigned get_unsigned(input string path,
                                                   input longint unsigned maximum);
    longint signed value;
    value = data.get_integer(path);
    if (value < 0 || $unsigned(value) > maximum) begin
      $fatal(1, "manifest value outside port range at %s", path);
    end
    return $unsigned(value);
  endfunction

  // Compara directamente contra la expectativa externa y rechaza X/Z.
  task automatic check_value(input string path, input logic [63:0] observed,
                             input longint unsigned maximum = 64'hffffffff);
    longint unsigned expected_value;
    expected_value = get_unsigned(path, maximum);
    assert (observed === expected_value)
    else begin
      $display("FAIL %s %s: expected %0h, observed %0h", data.case_id, path, expected_value,
               observed);
      $fatal(1, "IF stage output differs from manifest");
    end
  endtask

  // Cada observación incluye el PC visible y los cinco campos que recibirá IF/ID.
  task automatic check_outputs(input string path);
    check_value({path, "/debug_pc"}, debug_pc);
    check_value({path, "/ifid_input/valid"}, ifid_input.valid, 1);
    check_value({path, "/ifid_input/pc"}, ifid_input.pc);
    check_value({path, "/ifid_input/instruction"}, ifid_input.instruction);
    check_value({path, "/ifid_input/fetch_fault_valid"}, ifid_input.fetch_fault_valid, 1);
    check_value({path, "/ifid_input/fetch_fault_cause"}, ifid_input.fetch_fault_cause, 7);
  endtask

  // Mantiene las entradas estables alrededor del flanco funcional.
  task automatic clock_edge();
    clk = 1'b1;
    #1;
    clk = 1'b0;
    #1;
  endtask

  // Inicializa PC y carga palabras completas sin una imagen publicada ni avance de IF.
  task automatic load_fixture();
    reset = 1'b1;
    #1;
    clock_edge();
    reset = 1'b0;
    for (int index = 0; index < data.get_size("/inputs/if_initial_words"); index++) begin
      imem_write_index = WORD_INDEX_WIDTH
          '(get_unsigned($sformatf("/inputs/if_initial_words/%0d/index", index), INDEX_MAX));
      imem_write_data = word_t
          '(get_unsigned($sformatf("/inputs/if_initial_words/%0d/data", index), 64'hffffffff));
      imem_write_enable = 1'b1;
      #1;
      clock_edge();
    end
    imem_write_enable = 1'b0;
  endtask

  // El testbench presenta acciones; no calcula arbitraje, confirmación o captura de IF/ID.
  task automatic apply_step(input string path);
    reset = 1'(get_unsigned({path, "/reset"}, 1));
    prepare_init = 1'(get_unsigned({path, "/prepare_init"}, 1));
    act_normal = 1'(get_unsigned({path, "/act_normal"}, 1));
    act_redirect = 1'(get_unsigned({path, "/act_redirect"}, 1));
    redirect_target = word_t'(get_unsigned({path, "/redirect_target"}, 64'hffffffff));
    loaded_image_size_bytes =
        IMAGE_SIZE_WIDTH'(get_unsigned({path, "/loaded_image_size_bytes"}, IMAGE_SIZE_MAX));
    imem_write_index = WORD_INDEX_WIDTH'(get_unsigned({path, "/imem_write_index"}, INDEX_MAX));
    imem_write_data = word_t'(get_unsigned({path, "/imem_write_data"}, 64'hffffffff));
    imem_write_enable = 1'(get_unsigned({path, "/imem_write_enable"}, 1));
  endtask

  initial begin
    data.load();
    if (IMEM_CAPACITY_BYTES !== get_unsigned("/inputs/C", 64'h100000000)) begin
      $fatal(1, "elaborated IF capacity differs from manifest");
    end
    if (data.get_size(
            "/inputs/if_steps"
        ) == 0 || data.get_size(
            "/inputs/if_steps"
        ) != data.get_size(
            "/expected/if_steps"
        )) begin
      $fatal(1, "IF steps and expectations must have the same nonzero length");
    end
    load_fixture();
    for (int step = 0; step < data.get_size("/inputs/if_steps"); step++) begin
      apply_step($sformatf("/inputs/if_steps/%0d", step));
      #1;
      check_outputs($sformatf("/expected/if_steps/%0d/before_edge", step));
      for (
          int edge_index = 0;
          edge_index < get_unsigned($sformatf("/inputs/if_steps/%0d/clock_edges", step), 1000);
          edge_index++
      ) begin
        clock_edge();
        check_outputs($sformatf("/expected/if_steps/%0d/after_edge", step));
      end
      #1;
      check_outputs($sformatf("/expected/if_steps/%0d/after_edge", step));
    end
    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule

// Reutiliza los rechazos del paquete contra el guard real de la etapa y sus recursos.
module if_stage_config_tb #(
    parameter system_pkg::memory_capacity_t IMEM_CAPACITY_BYTES = 64'd0
);
  import system_pkg::*;

  if_id_t unused_ifid;
  word_t  unused_pc;
  string  case_id;

  if_stage #(
      .IMEM_CAPACITY_BYTES(IMEM_CAPACITY_BYTES)
  ) dut (
      .clk                    (1'b0),
      .reset                  (1'b1),
      .prepare_init           (1'b0),
      .act_normal             (1'b0),
      .act_redirect           (1'b0),
      .redirect_target        ('0),
      .loaded_image_size_bytes('0),
      .imem_write_index       ('0),
      .imem_write_data        ('0),
      .imem_write_enable      (1'b0),
      .ifid_input             (unused_ifid),
      .debug_pc               (unused_pc)
  );

  initial begin
    #1;
    $finish;
  end

  final begin
    if (!memory_capacity_valid(IMEM_CAPACITY_BYTES) && $value$plusargs("CASE=%s", case_id)) begin
      $display("REJECT %s %s", case_id, CONFIG_INVALID_CAPACITY);
    end
  end
endmodule
