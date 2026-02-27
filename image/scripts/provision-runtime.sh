#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATE_FILE="$ROOT_DIR/out/work/state/build-state.env"
[[ -f "$STATE_FILE" ]] || { echo "ERROR: missing state file: $STATE_FILE" >&2; exit 1; }
# shellcheck disable=SC1090
source "$STATE_FILE"

[[ -d "$MNT_ROOT" ]] || { echo "ERROR: missing mounted rootfs: $MNT_ROOT" >&2; exit 1; }

cleanup_chroot_mounts() {
  set +e
  for p in run proc sys dev; do
    if findmnt -rn "$MNT_ROOT/$p" >/dev/null 2>&1; then
      umount "$MNT_ROOT/$p"
    fi
  done
  set -e
}
trap cleanup_chroot_mounts EXIT

mount --bind /dev "$MNT_ROOT/dev"
mount --bind /sys "$MNT_ROOT/sys"
mount --bind /proc "$MNT_ROOT/proc"
mount --bind /run "$MNT_ROOT/run"

CHROOT_PREFIX=(chroot "$MNT_ROOT")
if file "$MNT_ROOT/bin/sh" | grep -qiE 'aarch64|arm64'; then
  command -v qemu-aarch64-static >/dev/null 2>&1 || { echo "ERROR: qemu-aarch64-static required for arm64 chroot" >&2; exit 1; }
  cp /usr/bin/qemu-aarch64-static "$MNT_ROOT/usr/bin/qemu-aarch64-static"
  CHROOT_PREFIX=(chroot "$MNT_ROOT" /usr/bin/qemu-aarch64-static)
fi

"${CHROOT_PREFIX[@]}" /usr/bin/env bash -lc '
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends curl ca-certificates gnupg git xz-utils

# Install deterministic Node >=22.12.0 (avoid distro lag/conflicts)
NODE_VER="v22.12.0"
NODE_TAR="node-${NODE_VER}-linux-arm64.tar.xz"
curl -fsSL "https://nodejs.org/dist/${NODE_VER}/${NODE_TAR}" -o "/tmp/${NODE_TAR}"
mkdir -p /usr/local/lib/nodejs
rm -rf "/usr/local/lib/nodejs/node-${NODE_VER}-linux-arm64"
tar -xJf "/tmp/${NODE_TAR}" -C /usr/local/lib/nodejs
ln -sf "/usr/local/lib/nodejs/node-${NODE_VER}-linux-arm64/bin/node" /usr/local/bin/node
ln -sf "/usr/local/lib/nodejs/node-${NODE_VER}-linux-arm64/bin/npm" /usr/local/bin/npm
ln -sf "/usr/local/lib/nodejs/node-${NODE_VER}-linux-arm64/bin/npx" /usr/local/bin/npx

NODE_ACTUAL="$(node -v | sed 's/^v//')"
if ! dpkg --compare-versions "$NODE_ACTUAL" ge "22.12.0"; then
  echo "ERROR: installed node version is below 22.12.0: $NODE_ACTUAL" >&2
  exit 1
fi

npm install -g openclaw@latest

OPENCLAW_PATH="$(command -v openclaw || true)"
if [[ -z "$OPENCLAW_PATH" || ! -x "$OPENCLAW_PATH" ]]; then
  echo "ERROR: openclaw not found in chroot after install" >&2
  exit 1
fi

mkdir -p /etc/default
cat >/etc/default/clawos-path <<EOF
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
EOF

{
  echo "node: $(command -v node) $(node -v)"
  echo "npm: $(command -v npm) $(npm -v)"
  echo "openclaw: $(command -v openclaw)"
} >/var/log/clawos-openclaw-path.log

apt-get clean
rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /tmp/node-v*.tar.xz
'

echo "Runtime dependencies + OpenClaw CLI provisioned in image rootfs"
