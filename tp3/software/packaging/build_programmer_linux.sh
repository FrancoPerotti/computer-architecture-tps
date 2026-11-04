#!/usr/bin/env bash
set -euo pipefail
software_root=$(cd "$(dirname "$0")/.." && pwd)
repo_root=$(cd "$software_root/../.." && pwd)
python_root=$("$software_root/.venv/bin/python" -c 'import sys; print(sys.base_prefix)')
image='ghcr.io/francoperotti/tp3-dev@sha256:de4cb5924aed933ee4023a4235d275decf9779895797272ee8c7fd52e0ba6e7c'
docker run --rm --read-only --tmpfs /tmp:exec --user "$(id -u):$(id -g)" \
  -v "$repo_root:/work" -v "$python_root:/opt/python:ro" -w /work/tp3 "$image" \
  /opt/python/bin/python3.14 software/packaging/programmer_build.py
