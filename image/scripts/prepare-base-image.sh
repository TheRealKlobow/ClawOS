#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATE_DIR="$ROOT_DIR/out/work/state"
STATE_FILE="$STATE_DIR/build-state.env"

# A) platform/tooling gate + preflight + safe workdir creation
[[ -d "$ROOT_DIR/.git" ]] || { echo "ERROR: must run inside clawos repo root" >&2; exit 1; }
[[ "$(uname -s)" == "Linux" ]] || { echo "ERROR: Linux builder required" >&2; exit 1; }

for tool in losetup lsblk mount umount cp findmnt readlink; do
  command -v "$tool" >/dev/null 2>&1 || { echo "ERROR: missing required tool: $tool" >&2; exit 1; }
done

if ! command -v kpartx >/dev/null 2>&1; then
  echo "ERROR: missing required tool: kpartx" >&2
  exit 1
fi

(( EUID == 0 )) || { echo "ERROR: run as root (no sudo auto-escalation in scripts)" >&2; exit 1; }

OUT_WORK="$ROOT_DIR/out/work"
[[ ! -L "$OUT_WORK" ]] || { echo "ERROR: ./out/work must not be a symlink" >&2; exit 1; }

: "${BASE_IMAGE_PATH:=$ROOT_DIR/out/base/raspios-lite.img}"
: "${OUTPUT_IMAGE_PATH:=$ROOT_DIR/out/clawos-pi.img}"
: "${IMAGE_EXPAND_GB:=4}"

[[ -f "$BASE_IMAGE_PATH" ]] || { echo "ERROR: base image not found: $BASE_IMAGE_PATH" >&2; exit 1; }
mkdir -p "$(dirname "$OUTPUT_IMAGE_PATH")" "$ROOT_DIR/out/work/mnt-root" "$STATE_DIR"

cp "$BASE_IMAGE_PATH" "$OUTPUT_IMAGE_PATH"
truncate -s "+${IMAGE_EXPAND_GB}G" "$OUTPUT_IMAGE_PATH"

cat >"$STATE_FILE" <<EOF
ROOT_DIR=$ROOT_DIR
STATE_FILE=$STATE_FILE
OUTPUT_IMAGE_PATH=$OUTPUT_IMAGE_PATH
MNT_ROOT=$ROOT_DIR/out/work/mnt-root
KPARTX_USED=0
LOOP_DEV=
ROOT_PART=
BOOT_PART=
ERROR_CONTEXT=prepare-base-image
EOF

echo "Prepared output image: $OUTPUT_IMAGE_PATH"
echo "State file: $STATE_FILE"
