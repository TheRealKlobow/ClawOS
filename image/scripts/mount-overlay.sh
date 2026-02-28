#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATE_FILE="$ROOT_DIR/out/work/state/build-state.env"
[[ -f "$STATE_FILE" ]] || { echo "ERROR: missing state file: $STATE_FILE" >&2; exit 1; }
# shellcheck disable=SC1090
source "$STATE_FILE"

# C) mount + overlay inject
mount "$ROOT_PART" "$MNT_ROOT"

# copy overlays deterministically (no delete flags)
cp -a "$ROOT_DIR/image/overlays/." "$MNT_ROOT/"

# ensure script executable bits
chmod 0755 "$MNT_ROOT/usr/local/bin/clawos-bootstrap.sh"
chmod 0755 "$MNT_ROOT/usr/local/bin/openclaw-healthcheck.sh"
chmod 0755 "$MNT_ROOT/usr/local/bin/clawos-update"
if [[ -f "$MNT_ROOT/usr/local/bin/clawos-about" ]]; then
  chmod 0755 "$MNT_ROOT/usr/local/bin/clawos-about"
fi

cat >"$STATE_FILE" <<EOF
ROOT_DIR=$ROOT_DIR
STATE_FILE=$STATE_FILE
OUTPUT_IMAGE_PATH=$OUTPUT_IMAGE_PATH
MNT_ROOT=$MNT_ROOT
KPARTX_USED=$KPARTX_USED
LOOP_DEV=$LOOP_DEV
ROOT_PART=$ROOT_PART
BOOT_PART=$BOOT_PART
ROOT_MOUNTED=1
ERROR_CONTEXT=mount-overlay
EOF

echo "Overlay copied into rootfs: $MNT_ROOT"
