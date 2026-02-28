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

# Build-time runtime checks inside chroot only
"${CHROOT_PREFIX[@]}" /usr/bin/env bash -lc '
set -euo pipefail

NODE_BIN="$(command -v node || command -v nodejs || true)"
[[ -n "$NODE_BIN" ]] || { echo "ERROR: node/nodejs not found" >&2; exit 1; }

NPM_BIN="$(command -v npm || true)"
[[ -n "$NPM_BIN" ]] || { echo "ERROR: npm not found" >&2; exit 1; }

OPENCLAW_BIN="$(command -v openclaw || true)"
if [[ -n "$OPENCLAW_BIN" ]]; then
  [[ -x "$OPENCLAW_BIN" ]] || { echo "ERROR: openclaw exists but is not executable" >&2; exit 1; }
else
  [[ -f /opt/openclaw/scripts/run-node.mjs ]] || { echo "ERROR: neither openclaw binary nor /opt/openclaw/scripts/run-node.mjs found" >&2; exit 1; }
fi
'

UNIT_PATH="$MNT_ROOT/etc/systemd/system/openclaw.service"
[[ -f "$UNIT_PATH" ]] || { echo "ERROR: missing unit file: $UNIT_PATH" >&2; exit 1; }

grep -q '^WorkingDirectory=/opt/openclaw$' "$UNIT_PATH" || { echo "ERROR: WorkingDirectory missing/incorrect in openclaw.service" >&2; exit 1; }
grep -q '^ExecStart=/usr/bin/node /opt/openclaw/scripts/run-node.mjs gateway$' "$UNIT_PATH" || { echo "ERROR: ExecStart missing/incorrect in openclaw.service" >&2; exit 1; }

grep -q '^User=claw$' "$UNIT_PATH" || { echo "ERROR: openclaw.service must run as user claw" >&2; exit 1; }

echo "Rootfs runtime validation passed"
