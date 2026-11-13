`timescale 1ns / 1ps

// Host 8N1 común para los bancos de system_top. Las expectativas de cabecera
// y del cuerpo se expresan en los bancos, con el layout del protocolo.
module system_uart_host #(
    parameter longint unsigned BAUD_RATE      = 64'd3_125_000,
    parameter integer          MAX_USED_BYTES = 2048
) (
    input  logic serial_tx,
    output logic serial_rx = 1'b1
);
  import system_pkg::*;
  localparam longint unsigned TICK_HZ     = BAUD_RATE * UART_OVERSAMPLE_FACTOR;
  localparam integer          TICK_CYCLES = int'((FUNCTIONAL_CLOCK_HZ + TICK_HZ / 2) / TICK_HZ);
  localparam time             BIT_TIME    = 20 * TICK_CYCLES * UART_OVERSAMPLE_FACTOR;
  localparam time             FRAME_TIME  = 10 * BIT_TIME;

  logic [ 7:0] response   [DEBUG_FIXED_BYTES + 5*MAX_USED_BYTES];
  logic [39:0] used_count;

  task automatic send_byte(input logic [7:0] value, input bit reply = 0, input bit stop = 1);
    serial_rx = 0;
    #(BIT_TIME);
    for (integer index = 0; index < 8; index++) begin
      serial_rx = value[index];
      #(BIT_TIME);
    end
    serial_rx = stop;
    if (reply) #1ns;
    else #(BIT_TIME);
  endtask

  task automatic receive_byte(output logic [7:0] value);
    @(negedge serial_tx);
    #(BIT_TIME + BIT_TIME / 2);
    for (integer index = 0; index < 8; index++) begin
      value[index] = serial_tx;
      #(BIT_TIME);
    end
    if (serial_tx !== 1'b1) $fatal(1, "UART TX invalid stop for byte %h at %0t", value, $time);
  endtask

  task automatic expect_header(input logic [7:0] opcode, input logic [7:0] result);
    logic [7:0] value;
    receive_byte(value);
    if (value !== opcode)
      $fatal(1, "UART opcode expected %02x got %02x at %0t", opcode, value, $time);
    receive_byte(value);
    if (value !== result)
      $fatal(1, "UART result expected %02x got %02x at %0t", result, value, $time);
  endtask

  task automatic load_header(input logic [39:0] size, input logic [7:0] result = 8'h01);
    send_byte(8'h01);
    for (integer index = 0; index < 5; index++) send_byte(size[8*index+:8], index == 4);
    expect_header(8'h01, result);
  endtask

  task automatic read_snapshot(input logic [7:0] opcode, input logic [7:0] result);
    logic [7:0] value;
    expect_header(opcode, result);
    for (integer index = 0; index < DEBUG_FIXED_BYTES; index++) begin
      receive_byte(value);
      response[index] = value;
    end
    used_count = {response[227], response[226], response[225], response[224], response[223]};
    if ($isunknown(used_count) || used_count > 40'(MAX_USED_BYTES))
      $fatal(1, "invalid used_count %h", used_count);
    for (integer index = 0; index < 5 * int'(used_count); index++) begin
      receive_byte(value);
      response[DEBUG_FIXED_BYTES+index] = value;
    end
  endtask

  function automatic logic [31:0] word_at(input integer offset);
    return {response[offset+3], response[offset+2], response[offset+1], response[offset]};
  endfunction

  function automatic logic [63:0] cycles();
    return {word_at(10), word_at(6)};
  endfunction

  task automatic check_entry(input integer entry, input logic [31:0] address,
                             input logic [7:0] data);
    integer offset;
    offset = DEBUG_FIXED_BYTES + 5 * entry;
    if (entry >= int'(used_count) || word_at(offset) !== address || response[offset+4] !== data)
      $fatal(
          1,
          "DMEM entry %0d expected (%h,%h), got (%h,%h)",
          entry,
          address,
          data,
          word_at(
              offset
          ),
          response[offset+4]
      );
  endtask
endmodule
