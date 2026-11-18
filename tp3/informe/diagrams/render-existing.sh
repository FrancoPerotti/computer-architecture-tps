#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

for diagram in fsm-global forwarding bypass if-normal id-normal ex-r ex-load ex-branch mem-organizacion mem-load mem-store wb-organizacion fetch-fault; do
  DIAGRAM="$diagram" electron --headless --no-sandbox --disable-gpu \
    electron-render.cjs
done
