#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATE_FILE="$ROOT_DIR/out/work/state/build-state.env"
[[ -f "$STATE_FILE" ]] || { echo "ERROR: missing state file: $STATE_FILE" >&2; exit 1; }
# shellcheck disable=SC1090
source "$STATE_FILE"

# D) offline service enable + verify
WANTS_DIR="$MNT_ROOT/etc/systemd/system/multi-user.target.wants"
TIMERS_WANTS_DIR="$MNT_ROOT/etc/systemd/system/timers.target.wants"
NETONLINE_WANTS_DIR="$MNT_ROOT/etc/systemd/system/network-online.target.wants"
mkdir -p "$WANTS_DIR" "$TIMERS_WANTS_DIR" "$NETONLINE_WANTS_DIR"

ln -sfn /etc/systemd/system/clawos-bootstrap.service "$WANTS_DIR/clawos-bootstrap.service"
ln -sfn /etc/systemd/system/openclaw-gateway.service "$WANTS_DIR/openclaw-gateway.service"
ln -sfn /etc/systemd/system/openclaw.service "$WANTS_DIR/openclaw.service"
ln -sfn /etc/systemd/system/clawos-update.timer "$TIMERS_WANTS_DIR/clawos-update.timer"

if [[ -f "$MNT_ROOT/lib/systemd/system/systemd-networkd-wait-online.service" ]]; then
  ln -sfn /lib/systemd/system/systemd-networkd-wait-online.service "$NETONLINE_WANTS_DIR/systemd-networkd-wait-online.service"
elif [[ -f "$MNT_ROOT/usr/lib/systemd/system/systemd-networkd-wait-online.service" ]]; then
  ln -sfn /usr/lib/systemd/system/systemd-networkd-wait-online.service "$NETONLINE_WANTS_DIR/systemd-networkd-wait-online.service"
fi

# verify links and targets
for unit in clawos-bootstrap.service openclaw-gateway.service openclaw.service; do
  [[ -L "$WANTS_DIR/$unit" ]] || { echo "ERROR: missing symlink for $unit" >&2; exit 1; }
  target="$(readlink "$WANTS_DIR/$unit")"
  [[ "$target" == "/etc/systemd/system/$unit" ]] || {
    echo "ERROR: wrong symlink target for $unit -> $target" >&2
    exit 1
  }
  [[ -f "$MNT_ROOT/etc/systemd/system/$unit" ]] || {
    echo "ERROR: unit file not present in rootfs: $unit" >&2
    exit 1
  }
done

[[ -L "$TIMERS_WANTS_DIR/clawos-update.timer" ]] || { echo "ERROR: missing symlink for clawos-update.timer" >&2; exit 1; }
update_target="$(readlink "$TIMERS_WANTS_DIR/clawos-update.timer")"
[[ "$update_target" == "/etc/systemd/system/clawos-update.timer" ]] || {
  echo "ERROR: wrong symlink target for clawos-update.timer -> $update_target" >&2
  exit 1
}
[[ -f "$MNT_ROOT/etc/systemd/system/clawos-update.timer" ]] || {
  echo "ERROR: unit file not present in rootfs: clawos-update.timer" >&2
  exit 1
}

if [[ -L "$NETONLINE_WANTS_DIR/systemd-networkd-wait-online.service" ]]; then
  net_target="$(readlink "$NETONLINE_WANTS_DIR/systemd-networkd-wait-online.service")"
  if [[ "$net_target" != "/lib/systemd/system/systemd-networkd-wait-online.service" && "$net_target" != "/usr/lib/systemd/system/systemd-networkd-wait-online.service" ]]; then
    echo "ERROR: wrong symlink target for systemd-networkd-wait-online.service -> $net_target" >&2
    exit 1
  fi
fi

echo "Offline service links verified"
