#!/usr/bin/env bash
# Run the unchanged native product in an isolated Ubuntu userland and private Xvfb.
set -euo pipefail
if [[ $# != 3 || ( "$3" != ide && "$3" != sandbox && "$3" != installation ) ]]; then
  echo 'Uso: check_ubuntu_gui.sh ROOTFS_UBUNTU PRODUCTO_EXTRAIDO ide|sandbox|installation' >&2
  exit 2
fi
ubuntu_root=$(realpath "$1")
product_root=$(realpath "$2")
software_root=$(cd "$(dirname "$0")/.." && pwd)
repo_root=$(cd "$software_root/../.." && pwd)
node_runtime="$software_root/build/toolchain/node_modules/node/bin/node"
[[ -x "$ubuntu_root/usr/bin/xvfb-run" && -x "$node_runtime" ]]
[[ -f "$product_root/VERIFICATION-ONLY.txt" ]]
case "$3" in
  ide) command=("$node_runtime" tests/native-ide-smoke.cjs) ;;
  sandbox) command=("$node_runtime" tests/sandbox-smoke.cjs) ;;
  installation) command=(/usr/bin/python3 "$software_root/packaging/smoke_linux_installation.py" "$product_root" --gui) ;;
esac
# Bubblewrap cannot create bind mount parents after the root is made read-only.
# These directories belong only to the generated Ubuntu rootfs.
mkdir -p "$ubuntu_root$repo_root" "$ubuntu_root$product_root"
exec bwrap --unshare-user --unshare-pid --unshare-net --unshare-ipc --unshare-uts \
  --die-with-parent --ro-bind "$ubuntu_root" / --proc /proc --dev /dev --tmpfs /tmp \
  --bind "$repo_root" "$repo_root" --ro-bind "$product_root" "$product_root" \
  --chdir "$software_root/gui" --clearenv \
  --setenv PATH /usr/sbin:/usr/bin:/sbin:/bin --setenv LANG C.UTF-8 \
  --setenv HOME /tmp/viewrv-home --setenv XDG_CACHE_HOME /tmp/viewrv-cache \
  --setenv VIEWRV_PRODUCT "$product_root" --setenv VIEWRV_EVIDENCE_PREFIX pc-i08-ubuntu \
  --setenv LIBGL_ALWAYS_SOFTWARE 1 \
  /bin/bash -euo pipefail -c \
  'mkdir -p "$HOME" "$XDG_CACHE_HOME"; exec xvfb-run -a -s "-screen 0 1366x768x24" "$@"' \
  viewrv-ubuntu-check "${command[@]}"
