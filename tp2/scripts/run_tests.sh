#!/usr/bin/env bash
set -euo pipefail

tp2_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
sim_dir="${tp2_dir}/.sim"
mkdir -p "${sim_dir}"

testbenches=(
  alu_tb
  baud_tick_gen_tb
  fifo_tb
  uart_rx_tb
  uart_tx_tb
  uart_core_tb
  alu_uart_controller_tb
  alu_uart_top_tb
)

rtl_files=("${tp2_dir}"/rtl/*.sv)

if command -v iverilog >/dev/null 2>&1 && command -v vvp >/dev/null 2>&1; then
  for testbench in "${testbenches[@]}"; do
    echo "[TEST] ${testbench}"
    iverilog -g2012 -Wall -s "${testbench}" \
      -o "${sim_dir}/${testbench}.vvp" \
      "${rtl_files[@]}" "${tp2_dir}/tb/${testbench}.sv"
    vvp "${sim_dir}/${testbench}.vvp"
  done
elif command -v xvlog >/dev/null 2>&1 &&
     command -v xelab >/dev/null 2>&1 &&
     command -v xsim >/dev/null 2>&1; then
  for testbench in "${testbenches[@]}"; do
    echo "[TEST] ${testbench}"
    test_dir="${sim_dir}/${testbench}"
    mkdir -p "${test_dir}"
    pushd "${test_dir}" >/dev/null
    xvlog --sv "${rtl_files[@]}" "${tp2_dir}/tb/${testbench}.sv"
    xelab "${testbench}" -s "${testbench}_snapshot"
    xsim "${testbench}_snapshot" -runall
    popd >/dev/null
  done
else
  echo "ERROR: se necesita Icarus Verilog (iverilog/vvp) o Vivado XSim." >&2
  exit 1
fi

echo "PASS: ${#testbenches[@]} testbenches completados"
