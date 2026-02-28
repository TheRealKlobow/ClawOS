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
NODE_VERSION="$(node -v | sed "s/^v//")"
dpkg --compare-versions "$NODE_VERSION" ge 22 || { echo "ERROR: node version must be >=22 (got ${NODE_VERSION})" >&2; exit 1; }

NPM_BIN="$(command -v npm || true)"
[[ -n "$NPM_BIN" ]] || { echo "ERROR: npm not found" >&2; exit 1; }
COREPACK_BIN="$(command -v corepack || true)"
[[ -n "$COREPACK_BIN" ]] || { echo "ERROR: corepack not found" >&2; exit 1; }
PNPM_BIN="$(command -v pnpm || true)"
[[ -n "$PNPM_BIN" ]] || { echo "ERROR: pnpm not found" >&2; exit 1; }

[[ -d /opt/openclaw ]] || { echo "ERROR: /opt/openclaw missing" >&2; exit 1; }
[[ -f /opt/openclaw/openclaw.mjs ]] || { echo "ERROR: /opt/openclaw/openclaw.mjs missing" >&2; exit 1; }
[[ -f /opt/openclaw/dist/entry.mjs || -f /opt/openclaw/dist/entry.js ]] || { echo "ERROR: OpenClaw dist entry missing" >&2; exit 1; }
[[ -f /opt/openclaw/dist/control-ui/index.html ]] || { echo "ERROR: OpenClaw Control UI runtime index missing (/opt/openclaw/dist/control-ui/index.html)" >&2; exit 1; }
[[ -f /etc/openclaw/version ]] || { echo "ERROR: /etc/openclaw/version missing" >&2; exit 1; }
[[ -f /etc/clawos/openclaw-ref ]] || { echo "ERROR: /etc/clawos/openclaw-ref missing" >&2; exit 1; }
owner="$(stat -c %U:%G /opt/openclaw)"
[[ "$owner" == "claw:claw" ]] || { echo "ERROR: /opt/openclaw owner must be claw:claw (got $owner)" >&2; exit 1; }

command -v openclaw >/dev/null 2>&1 || { echo "ERROR: openclaw CLI is missing from PATH" >&2; exit 1; }
openclaw --help >/dev/null 2>&1 || { echo "ERROR: openclaw --help failed" >&2; exit 1; }

id claw >/dev/null 2>&1 || { echo "ERROR: user claw missing" >&2; exit 1; }
id -nG claw | tr " " "\n" | grep -qx sudo || { echo "ERROR: user claw is not in sudo group" >&2; exit 1; }
su -s /bin/bash claw -c "sudo -n whoami" | grep -qx root || { echo "ERROR: sudo whoami failed for claw user" >&2; exit 1; }

if [[ -x /bin/systemctl || -x /usr/bin/systemctl ]]; then
  systemctl is-enabled ssh | grep -qx enabled || { echo "ERROR: ssh service is not enabled" >&2; exit 1; }
else
  echo "ERROR: systemctl is not available in image" >&2
  exit 1
fi
'

UNIT_PATH="$MNT_ROOT/etc/systemd/system/openclaw.service"
[[ -f "$UNIT_PATH" ]] || { echo "ERROR: missing unit file: $UNIT_PATH" >&2; exit 1; }

grep -q '^WorkingDirectory=/opt/openclaw$' "$UNIT_PATH" || { echo "ERROR: WorkingDirectory missing/incorrect in openclaw.service" >&2; exit 1; }
grep -q '^ExecStart=/usr/local/bin/openclaw gateway run --allow-unconfigured$' "$UNIT_PATH" || { echo "ERROR: ExecStart missing/incorrect in openclaw.service" >&2; exit 1; }
grep -q '^EnvironmentFile=-/etc/openclaw/openclaw.env$' "$UNIT_PATH" || { echo "ERROR: EnvironmentFile for openclaw.env missing" >&2; exit 1; }

grep -q '^User=claw$' "$UNIT_PATH" || { echo "ERROR: openclaw.service must run as user claw" >&2; exit 1; }

SSH_WANTS="$MNT_ROOT/etc/systemd/system/multi-user.target.wants/ssh.service"
[[ -L "$SSH_WANTS" ]] || { echo "ERROR: ssh symlink missing in multi-user.target.wants" >&2; exit 1; }
ssh_link_target="$(readlink "$SSH_WANTS")"
if [[ "$ssh_link_target" != "/lib/systemd/system/ssh.service" && "$ssh_link_target" != "/usr/lib/systemd/system/ssh.service" ]]; then
  echo "ERROR: ssh symlink target invalid: $ssh_link_target" >&2
  exit 1
fi

echo "Rootfs runtime validation passed"
