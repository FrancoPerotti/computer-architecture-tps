#!/usr/bin/env bash
set -euo pipefail

# Localiza la CLI junto al script y conserva sus argumentos y código de salida.
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$script_dir/run_tests.py" "$@"
