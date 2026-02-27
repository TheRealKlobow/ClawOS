#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATE_FILE="$ROOT_DIR/out/work/state/build-state.env"
[[ -f "$STATE_FILE" ]] || { echo "ERROR: missing state file: $STATE_FILE" >&2; exit 1; }
# shellcheck disable=SC1090
source "$STATE_FILE"

# D) offline service enable + verify
WANTS_DIR="$MNT_ROOT/etc/systemd/system/multi-user.target.wants"
mkdir -p "$WANTS_DIR"

ln -sfn /etc/systemd/system/clawos-bootstrap.service "$WANTS_DIR/clawos-bootstrap.service"
ln -sfn /etc/systemd/system/openclaw-gateway.service "$WANTS_DIR/openclaw-gateway.service"

# verify links and targets
for unit in clawos-bootstrap.service openclaw-gateway.service; do
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

echo "Offline service links verified"
