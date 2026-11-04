#!/usr/bin/env bash
set -euo pipefail
product_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
exec "$product_root/viewrv-maintenance" install --source "$product_root" "$@"
