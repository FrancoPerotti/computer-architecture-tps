SHELL := /bin/bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := help

# Solo fuentes propias; las salidas generadas de Vivado y build quedan fuera.
SV_DIRS := rtl tb scripts/tests/fixtures
PY_DIR := scripts
SH_SOURCES := scripts/run_tests.sh
RTL_SOURCES := rtl/system_pkg.sv rtl/global_fsm.sv
REPORTS := build/reports
VERIBLE_LINT := verible-verilog-lint --ruleset=none --rules_config=.rules.verible_lint
VERIBLE_FORMAT := verible-verilog-format --flagfile=.verible-format-flags
export TESTS

.PHONY: help format format-check lint validate test-infra test-rtl test check
help:
	@printf '%s\n' \
	  'make format        Aplicar formato SystemVerilog, Python y Bash' \
	  'make format-check  Comprobar formato sin modificar fuentes' \
	  'make lint          Verible, Verilator, Ruff y ShellCheck' \
	  'make validate      Validar esquemas, catálogo y fuentes registradas' \
	  'make test-infra    Probar la infraestructura de pruebas' \
	  'make test-rtl      Ejecutar todos los casos implementados' \
	  'make test-rtl TESTS="ID1 ID2"  Seleccionar grupos o casos' \
	  'make test          Infraestructura y simulaciones RTL' \
	  'make check         Todas las comprobaciones anteriores'

format:
	find $(SV_DIRS) -type f -name '*.sv' -print0 | xargs -0 -r $(VERIBLE_FORMAT) --inplace
	ruff check --select I --fix $(PY_DIR)
	ruff format $(PY_DIR)
	shfmt -ln bash -i 2 -w $(SH_SOURCES)

format-check:
	find $(SV_DIRS) -type f -name '*.sv' -print0 | xargs -0 -r -n 1 $(VERIBLE_FORMAT) --verify
	ruff format --check $(PY_DIR)
	shfmt -ln bash -i 2 -d $(SH_SOURCES)

lint:
	find $(SV_DIRS) -type f -name '*.sv' -print0 | xargs -0 -r $(VERIBLE_LINT)
	verilator --lint-only --language 1800-2012 $(RTL_SOURCES)
	ruff check $(PY_DIR)
	shellcheck --shell=bash $(SH_SOURCES)

validate:
	check-jsonschema --check-metaschema docs/verification/cases.schema.json docs/verification/results.schema.json
	python3 scripts/run_tests.py --validate

test-infra:
	@mkdir -p $(REPORTS)
	python3 -m unittest discover -s scripts/tests -v 2>&1 | tee $(REPORTS)/infrastructure.log

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

test: test-infra test-rtl
check: format-check lint validate test
