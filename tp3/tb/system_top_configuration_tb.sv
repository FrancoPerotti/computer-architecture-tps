`timescale 1ns / 1ps

module system_top_configuration_tb #(
    parameter system_pkg::memory_capacity_t IMEM_CAPACITY_BYTES = 64'd1024,
    parameter system_pkg::memory_capacity_t DMEM_CAPACITY_BYTES = 64'd2048
);
  tp3_case_data data ();
  system_top #(
      .IMEM_CAPACITY_BYTES(IMEM_CAPACITY_BYTES),
      .DMEM_CAPACITY_BYTES(DMEM_CAPACITY_BYTES)
  ) dut (
      .clk               (1'b0),
      .reset             (1'b1),
      .serial_rx         (1'b1),
      .serial_tx         (),
      .uart_reset_request()
  );

  initial begin
    data.load();
    #1;
    if (dut.processor_inst.IMEM_CAPACITY_BYTES != data.get_integer(
            "/inputs/IMEM_C"
        ) || dut.controller_inst.IMEM_CAPACITY_BYTES != data.get_integer(
            "/inputs/IMEM_C"
        ) || dut.processor_inst.DMEM_CAPACITY_BYTES != data.get_integer(
            "/inputs/DMEM_C"
        ) || dut.serializer_inst.DMEM_CAPACITY_BYTES != data.get_integer(
            "/inputs/DMEM_C"
        ))
      $fatal(1, "memory profile did not propagate through system_top");
    if ($bits(
            dut.load_size_bytes
        ) != data.get_integer(
            "/expected/processor_widths/image_size"
        ) || $bits(
            dut.load_byte_offset
        ) != data.get_integer(
            "/expected/processor_widths/imem_byte"
        ) || $bits(
            dut.debug_dmem_addr
        ) != data.get_integer(
            "/expected/processor_widths/dmem_byte"
        ))
      $fatal(1, "system boundary width differs from the selected profile");
    if (dut.uart_inst.CLK_FREQ_HZ != 50_000_000 || dut.uart_inst.BAUD_RATE != 19_200 ||
        dut.uart_inst.OVERSAMPLE != 16 || dut.uart_inst.rx_fifo.DEPTH != 4 ||
        dut.uart_inst.tx_fifo.DEPTH != 4)
      $fatal(1, "nominal UART configuration differs from the catalogue");
    $display("PASS %s", data.case_id);
    $finish;
  end
endmodule
