`timescale 1ns / 1ps

module serializer_count_width_tb;
  tp3_case_data data ();
  logic       clk = 0;
  logic       reset = 1;
  wire  [7:0] w_data;
  wire        wr_uart;

  response_serializer #(
      .DMEM_CAPACITY_BYTES(64'h1_0000_0000)
  ) dut (
      .clk,
      .reset,
      .tx_full            (1'b0),
      .tx_done_tick       (1'b0),
      .w_data,
      .wr_uart,
      .response_start     (1'b0),
      .response_opcode    (8'd0),
      .response_result    (8'd0),
      .response_with_debug(1'b0),
      .debug_dmem_data    (8'd0),
      .debug_dmem_used    (1'b0)
  );
  always #10ns clk = ~clk;

  initial begin
    data.load();
    @(negedge clk);
    reset          = 0;
    // This arithmetic vector needs the inclusive counter, without a DMEM array.
    dut.used_count = 33'(data.get_integer("/inputs/used_count"));
    dut.state      = dut.PREPARE_COUNT;
    for (integer index = 0; index < 5; index++) begin
      @(negedge clk);
      if (!wr_uart || w_data !== 8'(data.get_integer(
              $sformatf("/expected/count_bytes/%0d", index)
          )))
        $fatal(1, "count byte %0d incorrect: %02x", index, w_data);
      @(negedge clk);
    end
    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule
