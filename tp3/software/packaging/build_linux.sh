#!/usr/bin/env bash
# Construir Python en la base Ubuntu 24.04 fijada del TP3, sin escribir el rootfs.
set -euo pipefail
software_root=$(cd "$(dirname "$0")/.." && pwd)
repo_root=$(cd "$software_root/../.." && pwd)
python_root=$("$software_root/.venv/bin/python" -c 'import sys; print(sys.base_prefix)')
image='ghcr.io/francoperotti/tp3-dev@sha256:de4cb5924aed933ee4023a4235d275decf9779895797272ee8c7fd52e0ba6e7c'
docker run --rm --read-only --tmpfs /tmp --user "$(id -u):$(id -g)" \
  -e PIP_CACHE_DIR=/tmp/viewrv-build/pip -e PYINSTALLER_CONFIG_DIR=/tmp/viewrv-build/pyinstaller \
  -v "$repo_root:/work" -v "$python_root:/opt/python:ro" \
  -w /work/tp3 "$image" bash -euo pipefail -c '
    mkdir -p /tmp/apt-lists/partial /tmp/apt-cache software/build/ubuntu-tools/debs
    apt-get -o Dir::State::lists=/tmp/apt-lists -o Dir::Cache=/tmp/apt-cache update > software/build/ubuntu-apt.log 2>&1
    cd software/build/ubuntu-tools/debs
    apt-get -o Dir::State::lists=/tmp/apt-lists download binutils binutils-common binutils-x86-64-linux-gnu libbinutils libctf0 libctf-nobfd0 libgprofng0 libjansson4 libsframe1 >> ../../ubuntu-apt.log 2>&1
    for package in ./*.deb; do dpkg-deb -x "$package" ..; done
    cd /work/tp3
    export PATH="/work/tp3/software/build/ubuntu-tools/usr/bin:$PATH"
    export LD_LIBRARY_PATH=/work/tp3/software/build/ubuntu-tools/usr/lib/x86_64-linux-gnu
    /opt/python/bin/python3.14 -m venv software/build/ubuntu-venv
    software/build/ubuntu-venv/bin/python -m pip install --require-hashes -r software/requirements-linux.lock > software/build/ubuntu-dependencies.log 2>&1
    software/build/ubuntu-venv/bin/python software/packaging/build_python.py "$@" > software/build/ubuntu-packaging.log 2>&1
  ' viewrv-build "$@"
