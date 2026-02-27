#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATE_FILE="$ROOT_DIR/out/work/state/build-state.env"
[[ -f "$STATE_FILE" ]] || { echo "ERROR: missing state file: $STATE_FILE" >&2; exit 1; }
# shellcheck disable=SC1090
source "$STATE_FILE"

# B) loop attach + partition mapping + detection
LOOP_DEV="$(losetup --find --show --partscan "$OUTPUT_IMAGE_PATH")"
LOOP_BASE="$(basename "$LOOP_DEV")"

mapfile -t PARTITIONS < <(kpartx -av "$LOOP_DEV" | awk '{print $3}' | sed 's#^#/dev/mapper/#')
(( ${#PARTITIONS[@]} > 0 )) || { echo "ERROR: no partitions mapped by kpartx" >&2; exit 1; }
KPARTX_USED=1

EXT4_PARTS=()
BOOT_PART=""
for part in "${PARTITIONS[@]}"; do
  fstype="$(lsblk -no FSTYPE "$part" | tr -d '[:space:]')"
  partlabel="$(lsblk -no PARTLABEL "$part" | tr -d '[:space:]')"

  if [[ "$fstype" == "ext4" ]]; then
    EXT4_PARTS+=("$part")
  fi
  if [[ "$fstype" == "vfat" || "$fstype" == "fat" || "$fstype" == "fat32" ]]; then
    if [[ -z "$BOOT_PART" ]]; then
      BOOT_PART="$part"
    fi
  fi
  # prefer PARTLABEL hints for rootfs but still enforce single ext4 hard-check below
  if [[ "$partlabel" == "rootfs" || "$partlabel" == "ROOTFS" ]]; then
    ROOT_PART="$part"
  fi
done

# Final hard rules: single ext4 candidate only, no heuristics
if (( ${#EXT4_PARTS[@]} == 0 )); then
  echo "ERROR: no ext4 root partition candidate found" >&2
  exit 1
fi
if (( ${#EXT4_PARTS[@]} > 1 )); then
  echo "ERROR: multiple ext4 root candidates found: ${EXT4_PARTS[*]}" >&2
  exit 1
fi
ROOT_PART="${EXT4_PARTS[0]}"

# Hard rootfs content validation
TMP_CHECK="$ROOT_DIR/out/work/mnt-root-check"
mkdir -p "$TMP_CHECK"
mount -o ro "$ROOT_PART" "$TMP_CHECK"
if [[ ! -f "$TMP_CHECK/etc/os-release" || ! -x "$TMP_CHECK/bin/sh" ]]; then
  umount "$TMP_CHECK" || true
  echo "ERROR: root partition validation failed (need /etc/os-release and /bin/sh)" >&2
  exit 1
fi
umount "$TMP_CHECK"
rmdir "$TMP_CHECK" || true

cat >"$STATE_FILE" <<EOF
ROOT_DIR=$ROOT_DIR
STATE_FILE=$STATE_FILE
OUTPUT_IMAGE_PATH=$OUTPUT_IMAGE_PATH
MNT_ROOT=$MNT_ROOT
KPARTX_USED=$KPARTX_USED
LOOP_DEV=$LOOP_DEV
ROOT_PART=$ROOT_PART
BOOT_PART=$BOOT_PART
ERROR_CONTEXT=inject-overlay
EOF

echo "Loop mapped: $LOOP_DEV"
echo "Root partition: $ROOT_PART"
