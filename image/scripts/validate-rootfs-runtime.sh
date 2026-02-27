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

# Build-time runtime checks inside chroot only
chroot "$MNT_ROOT" /usr/bin/env bash -lc '
set -euo pipefail

NODE_BIN="$(command -v node || command -v nodejs || true)"
[[ -n "$NODE_BIN" ]] || { echo "ERROR: node/nodejs not found" >&2; exit 1; }

NPM_BIN="$(command -v npm || true)"
[[ -n "$NPM_BIN" ]] || { echo "ERROR: npm not found" >&2; exit 1; }

OPENCLAW_BIN="$(command -v openclaw || true)"
[[ -n "$OPENCLAW_BIN" ]] || { echo "ERROR: openclaw not found" >&2; exit 1; }
[[ -x "$OPENCLAW_BIN" ]] || { echo "ERROR: openclaw not executable" >&2; exit 1; }

openclaw --version >/dev/null
'

UNIT_PATH="$MNT_ROOT/etc/systemd/system/openclaw-gateway.service"
[[ -f "$UNIT_PATH" ]] || { echo "ERROR: missing unit file: $UNIT_PATH" >&2; exit 1; }

grep -q '^ExecCondition=' "$UNIT_PATH" || { echo "ERROR: ExecCondition missing in openclaw-gateway.service" >&2; exit 1; }
grep -q '^EnvironmentFile=-/etc/default/clawos-path$' "$UNIT_PATH" || { echo "ERROR: EnvironmentFile=-/etc/default/clawos-path missing" >&2; exit 1; }

awk '
  /^Environment=.*PATH=/ { count++ }
  END {
    if (count > 1) {
      print "ERROR: duplicate PATH Environment definitions in openclaw-gateway.service" > "/dev/stderr"
      exit 1
    }
  }
' "$UNIT_PATH"

echo "Rootfs runtime validation passed"
