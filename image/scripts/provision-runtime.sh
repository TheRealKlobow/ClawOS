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
apt-get install -y --no-install-recommends curl ca-certificates gnupg git

nodesource_ok=0
if curl -fsSL https://deb.nodesource.com/setup_22.x -o /tmp/nodesource-setup.sh; then
  if bash /tmp/nodesource-setup.sh; then
    if apt-get install -y --no-install-recommends nodejs; then
      nodesource_ok=1
    fi
  fi
fi

if [[ "$nodesource_ok" -ne 1 ]]; then
  apt-get install -y --no-install-recommends nodejs npm
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

which openclaw >/var/log/clawos-openclaw-path.log
'

echo "Runtime dependencies + OpenClaw CLI provisioned in image rootfs"
