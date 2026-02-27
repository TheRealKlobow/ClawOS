#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATE_FILE="$ROOT_DIR/out/work/state/build-state.env"
[[ -f "$STATE_FILE" ]] || { echo "ERROR: missing state file: $STATE_FILE" >&2; exit 1; }
# shellcheck disable=SC1090
source "$STATE_FILE"

[[ -n "${LOOP_DEV:-}" ]] || { echo "ERROR: LOOP_DEV missing from state" >&2; exit 1; }
[[ -n "${ROOT_PART:-}" ]] || { echo "ERROR: ROOT_PART missing from state" >&2; exit 1; }

command -v parted >/dev/null 2>&1 || { echo "ERROR: parted is required" >&2; exit 1; }
command -v e2fsck >/dev/null 2>&1 || { echo "ERROR: e2fsck is required" >&2; exit 1; }
command -v resize2fs >/dev/null 2>&1 || { echo "ERROR: resize2fs is required" >&2; exit 1; }

# Required sequence: grow partition 2 to end-of-disk, then grow ext4 fs
parted -s "$LOOP_DEV" resizepart 2 100%
partprobe "$LOOP_DEV" || true

# Rebuild mapper nodes after table change
if [[ "${KPARTX_USED:-0}" == "1" ]]; then
  kpartx -dv "$LOOP_DEV" >/dev/null 2>&1 || true
  kpartx -av "$LOOP_DEV" >/dev/null
fi

# ROOT_PART path stays /dev/mapper/<loop>p2 for kpartx flow
e2fsck -fy "$ROOT_PART"
resize2fs "$ROOT_PART"

echo "Expanded root partition and filesystem: $ROOT_PART"
