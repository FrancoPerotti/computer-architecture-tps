SHELL := /bin/bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := help

# Solo fuentes propias; las salidas generadas de Vivado y build quedan fuera.
SV_DIRS := rtl tb scripts/tests/fixtures
PY_DIR := scripts software
CPU_REVIEW_TOOL := tools/verification/check_cpu_structure.py
SH_SOURCES := scripts/run_tests.sh
RTL_SOURCES := rtl/system_pkg.sv rtl/decoder.sv rtl/immediate_generator.sv \
               rtl/register_file.sv rtl/id_fault_check.sv rtl/load_use_detector.sv \
               rtl/forwarding_unit.sv rtl/alu.sv rtl/flow_control.sv rtl/ex_fault_check.sv \
               rtl/id_stage.sv rtl/ex_stage.sv \
               rtl/fetch_fault_check.sv rtl/instruction_memory.sv rtl/if_stage.sv \
               rtl/mem_decode.sv rtl/dmem_write_control.sv rtl/load_select_extend.sv \
               rtl/data_memory.sv rtl/mem_stage.sv rtl/wb_stage.sv \
               rtl/if_id_register.sv rtl/id_ex_register.sv rtl/ex_mem_register.sv \
               rtl/mem_wb_register.sv rtl/pipeline_hazard_control.sv \
               rtl/global_fsm.sv rtl/execution_control.sv rtl/loader.sv \
               rtl/session_preparation.sv
RTL_TOPS := decoder immediate_generator register_file id_fault_check load_use_detector \
            forwarding_unit alu flow_control id_stage ex_stage mem_decode \
            dmem_write_control load_select_extend wb_stage \
            if_id_register id_ex_register ex_mem_register mem_wb_register pipeline_hazard_control \
            execution_control loader session_preparation
IMEM_RTL_TOPS := fetch_fault_check instruction_memory if_stage
IMEM_LINT_CAPACITIES := 4 1000 1024
EX_FAULT_RTL_TOPS := ex_fault_check
EX_FAULT_LINT_CAPACITIES := 4 1000 2048 4294967296
DMEM_RTL_TOPS := data_memory mem_stage
DMEM_LINT_CAPACITIES := 4 1000 2048
PROCESSOR_SOURCES := $(RTL_SOURCES) rtl/processor_top.sv
REPORTS := build/reports
VERIBLE_LINT := verible-verilog-lint --ruleset=none --rules_config=.rules.verible_lint
VERIBLE_FORMAT := verible-verilog-format --flagfile=.verible-format-flags
export TESTS

.PHONY: help format format-check lint lint-processor review-cpu validate test-infra test-software test-rtl test check
help:
	@printf '%s\n' \
	  'make format        Aplicar formato SystemVerilog, Python y Bash' \
	  'make format-check  Comprobar formato sin modificar fuentes' \
	  'make lint          Verible, Verilator, Ruff y ShellCheck' \
	  'make lint-processor  Analizar el CPU real en tres configuraciones' \
	  'make review-cpu    Contrastar jerarquía, payloads y recursos del CPU con el inventario' \
	  'make validate      Validar esquemas, catálogo y fuentes registradas' \
	  'make test-infra    Probar la infraestructura de pruebas' \
	  'make test-software Probar el software de PC' \
	  'make test-rtl      Ejecutar todos los casos implementados' \
	  'make test-rtl TESTS="ID1 ID2"  Seleccionar grupos o casos' \
	  'make test          Infraestructura, software de PC y simulaciones RTL' \
	  'make check         Todas las comprobaciones anteriores'

format:
	find $(SV_DIRS) -type f -name '*.sv' -print0 | xargs -0 -r $(VERIBLE_FORMAT) --inplace
	ruff check --select I --fix $(PY_DIR) $(CPU_REVIEW_TOOL)
	ruff format $(PY_DIR) $(CPU_REVIEW_TOOL)
	shfmt -ln bash -i 2 -w $(SH_SOURCES)

format-check:
	find $(SV_DIRS) -type f -name '*.sv' -print0 | xargs -0 -r -n 1 $(VERIBLE_FORMAT) --verify
	ruff format --check $(PY_DIR) $(CPU_REVIEW_TOOL)
	shfmt -ln bash -i 2 -d $(SH_SOURCES)

lint: lint-processor
	find $(SV_DIRS) -type f -name '*.sv' -print0 | xargs -0 -r $(VERIBLE_LINT)
	@for top in $(RTL_TOPS); do \
	  verilator --lint-only --language 1800-2012 --top-module "$$top" $(RTL_SOURCES); \
	done
	@for top in $(IMEM_RTL_TOPS); do \
	  for capacity in $(IMEM_LINT_CAPACITIES); do \
	    verilator --lint-only --language 1800-2012 --top-module "$$top" \
	      "-GIMEM_CAPACITY_BYTES=64'd$$capacity" $(RTL_SOURCES); \
	  done; \
	done
	@for top in $(EX_FAULT_RTL_TOPS); do \
	  for capacity in $(EX_FAULT_LINT_CAPACITIES); do \
	    verilator --lint-only --language 1800-2012 --top-module "$$top" \
	      "-GDMEM_CAPACITY_BYTES=64'd$$capacity" $(RTL_SOURCES); \
	  done; \
	done
	@for top in $(DMEM_RTL_TOPS); do \
	  for capacity in $(DMEM_LINT_CAPACITIES); do \
	    verilator --lint-only --language 1800-2012 --top-module "$$top" \
	      "-GDMEM_CAPACITY_BYTES=64'd$$capacity" $(RTL_SOURCES); \
	  done; \
	done
	ruff check $(PY_DIR) $(CPU_REVIEW_TOOL)
	shellcheck --shell=bash $(SH_SOURCES)

# REFERENCE, ALT_1000 y mínimo genérico; las cinco etapas son RTL de producción.
lint-processor:
	@for configuration in '1024 2048' '1000 1000' '4 4'; do \
	  read -r imem dmem <<< "$$configuration"; \
	  verilator --lint-only --language 1800-2012 --top-module processor_top \
	    "-GIMEM_CAPACITY_BYTES=64'd$$imem" "-GDMEM_CAPACITY_BYTES=64'd$$dmem" \
	    $(PROCESSOR_SOURCES); \
	done

# Esta revisión mecánica no sustituye el análisis de lógica local ni la implementación FPGA.
review-cpu:
	@mkdir -p $(REPORTS)
	@for configuration in \
	    '1024 2048 TEST-PLAT-001/C001 reference' \
	    '1000 1000 TEST-PLAT-001/C002 alt-1000' \
	    '4 4 TEST-PLAT-001/C003 minimum'; do \
	  read -r imem dmem case_id label <<< "$$configuration"; \
	  verilator --xml-only --language 1800-2012 --top-module processor_top \
	    "-GIMEM_CAPACITY_BYTES=64'd$$imem" "-GDMEM_CAPACITY_BYTES=64'd$$dmem" \
	    --xml-output "$(REPORTS)/cpu-$$label.xml" $(PROCESSOR_SOURCES); \
	  python3 $(CPU_REVIEW_TOOL) --xml "$(REPORTS)/cpu-$$label.xml" --case "$$case_id" \
	    --output "$(REPORTS)/cpu-$$label-structure.json"; \
	done

validate:
	check-jsonschema --check-metaschema docs/verification/cases.schema.json docs/verification/results.schema.json
	python3 scripts/run_tests.py --validate

test-infra:
	@mkdir -p $(REPORTS)
	python3 -m unittest discover -s scripts/tests -v 2>&1 | tee $(REPORTS)/infrastructure.log

test-software:
	@mkdir -p $(REPORTS)
	python3 -m unittest discover -s software/tests -v 2>&1 | tee $(REPORTS)/software.log

test-rtl:
	@mkdir -p $(REPORTS)
	@selectors=(--all); \
	if [[ -n "$${TESTS:-}" ]]; then \
	  read -r -a ids <<< "$$TESTS"; selectors=(); \
	  for id in "$${ids[@]}"; do selectors+=(--test "$$id"); done; \
	fi; \
	python3 scripts/run_tests.py "$${selectors[@]}" --format json \
	  --reports-dir $(REPORTS)/simulation \
	  2> >(tee $(REPORTS)/simulation.log >&2) | tee $(REPORTS)/results.json | \
	  PYTHONPATH=scripts python3 -c 'import json, sys; from run_tests import print_report; print_report(json.load(sys.stdin), "text")'

test: test-infra test-software test-rtl
check: format-check lint validate review-cpu test
