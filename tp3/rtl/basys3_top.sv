// Conecta los pines de Basys 3 con el sistema funcional del TP3.
module basys3_top #(
    parameter system_pkg::memory_profile_t MEMORY_PROFILE = system_pkg::REFERENCE,
    parameter longint unsigned             CLK_FREQ_HZ    = system_pkg::FUNCTIONAL_CLOCK_HZ
) (
    input  logic clk_100mhz_i,
    input  logic reset_btn_i,
    input  logic uart_rx_i,
    output logic uart_tx_o
);
  import system_pkg::*;

  if (memory_profile_supported(MEMORY_PROFILE)) begin : gen_supported_profile
    localparam memory_capacity_t IMEM_CAPACITY_BYTES = imem_capacity_bytes(MEMORY_PROFILE);
    localparam memory_capacity_t DMEM_CAPACITY_BYTES = dmem_capacity_bytes(MEMORY_PROFILE);

    logic clk;
    logic locked;
    logic reset;
    logic uart_reset_request;

    clock_generator clock_wizard (
        // Entradas
        .clk_in1(clk_100mhz_i),
        .reset  (reset_btn_i),

        // Salidas
        .clk_out1(clk),
        .locked
    );

    reset_sync reset_conditioner (
        // Entradas
        .clk,
        .async_reset_request(reset_btn_i | uart_reset_request | !locked),

        // Salidas
        .reset
    );

    system_top #(
        .IMEM_CAPACITY_BYTES(IMEM_CAPACITY_BYTES),
        .DMEM_CAPACITY_BYTES(DMEM_CAPACITY_BYTES),
        .CLK_FREQ_HZ        (CLK_FREQ_HZ)
    ) system (
        // Entradas
        .clk,
        .reset,
        .serial_rx(uart_rx_i),

        // Salidas
        .serial_tx(uart_tx_o),
        .uart_reset_request
    );
  end else begin : gen_unsupported_profile
    initial $fatal(1, "%s", CONFIG_UNSUPPORTED);
    assign uart_tx_o = 1'b1;
  end
endmodule
