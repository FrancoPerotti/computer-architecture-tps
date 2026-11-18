#!/usr/bin/env bash
set -euo pipefail

report_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/tp3-informe.XXXXXX")"
trap 'rm -rf "$build_dir"' EXIT

cd "$report_dir"
for pass in 1 2 3; do
  if ! pdflatex -interaction=nonstopmode -halt-on-error \
    -output-directory="$build_dir" tp3_riscv_pipeline.tex \
    > "$build_dir/pass-$pass.log" 2>&1; then
    cat "$build_dir/pass-$pass.log" >&2
    exit 1
  fi
done

# pdfTeX puede duplicar /Group al incorporar diagramas con transparencia.
qpdf --warning-exit-0 "$build_dir/tp3_riscv_pipeline.pdf" "$build_dir/final.pdf"
qpdf --check "$build_dir/final.pdf"
cp "$build_dir/final.pdf" "$report_dir/tp3_riscv_pipeline.pdf"
printf 'Informe generado en %s/tp3_riscv_pipeline.pdf\n' "$report_dir"
