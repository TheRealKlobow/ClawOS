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

OPENCLAW_REPO_URL="${OPENCLAW_REPO_URL:-https://github.com/openclaw/openclaw.git}"

"${CHROOT_PREFIX[@]}" /usr/bin/env OPENCLAW_REPO_URL="$OPENCLAW_REPO_URL" bash -lc '
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# Recover from interrupted package state if present
if [[ -f /var/lib/dpkg/lock-frontend || -f /var/lib/dpkg/lock ]]; then
  rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock || true
fi
dpkg --configure -a || true
apt-get -f install -y || true

apt-get update
apt-get install -y --no-install-recommends git curl ca-certificates

command -v node >/dev/null 2>&1 || { echo "ERROR: node not present; run provision-runtime first" >&2; exit 1; }
command -v npm >/dev/null 2>&1 || { echo "ERROR: npm not present; run provision-runtime first" >&2; exit 1; }

id claw >/dev/null 2>&1 || useradd -m -s /bin/bash claw

mkdir -p /opt
rm -rf /opt/openclaw
git clone --depth 1 "$OPENCLAW_REPO_URL" /opt/openclaw

cd /opt/openclaw
if [[ -f package-lock.json ]]; then
  npm ci --omit=dev
else
  npm install --omit=dev
fi

if npm run | grep -qE "^\s*build"; then
  npm run build || true
fi

if [[ -f /opt/openclaw/openclaw.mjs ]]; then
  chmod +x /opt/openclaw/openclaw.mjs
  ln -sf /opt/openclaw/openclaw.mjs /usr/local/bin/openclaw
fi

chown -R claw:claw /opt/openclaw

apt-get clean
rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*
'

echo "Installed OpenClaw source into /opt/openclaw"
