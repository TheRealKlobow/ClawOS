#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <path-to-raw-image.img>" >&2
  exit 1
fi

IMAGE_PATH="$1"
[[ -f "$IMAGE_PATH" ]] || { echo "ERROR: image not found: $IMAGE_PATH" >&2; exit 1; }

LOOP_DEV=""
ROOT_PART=""
MNT_ROOT=""

cleanup() {
  set +e
  if [[ -n "$MNT_ROOT" ]]; then
    sudo umount "$MNT_ROOT/dev/pts" 2>/dev/null || true
    sudo umount "$MNT_ROOT/dev" 2>/dev/null || true
    sudo umount "$MNT_ROOT/proc" 2>/dev/null || true
    sudo umount "$MNT_ROOT/sys" 2>/dev/null || true
    sudo umount "$MNT_ROOT" 2>/dev/null || true
    sudo rmdir "$MNT_ROOT" 2>/dev/null || true
  fi
  if [[ -n "$LOOP_DEV" ]]; then
    sudo losetup -d "$LOOP_DEV" 2>/dev/null || true
  fi
}
trap cleanup EXIT

LOOP_DEV="$(sudo losetup --find --show --partscan "$IMAGE_PATH")"
if [[ -b "${LOOP_DEV}p2" ]]; then
  ROOT_PART="${LOOP_DEV}p2"
else
  ROOT_PART="$(lsblk -lnpo NAME,PARTLABEL "$LOOP_DEV" | awk '$2 ~ /rootfs|ROOTFS/ {print $1; exit}')"
fi

[[ -n "$ROOT_PART" && -b "$ROOT_PART" ]] || {
  echo "ERROR: failed to locate root partition on $LOOP_DEV" >&2
  exit 1
}

MNT_ROOT="$(mktemp -d)"
sudo mount "$ROOT_PART" "$MNT_ROOT"
sudo mount --bind /dev "$MNT_ROOT/dev"
sudo mount -t proc proc "$MNT_ROOT/proc"
sudo mount -t sysfs sys "$MNT_ROOT/sys"
if [[ -d "$MNT_ROOT/dev/pts" ]]; then
  sudo mount --bind /dev/pts "$MNT_ROOT/dev/pts"
fi

CHROOT_CHECKS='set -euo pipefail

echo "[validate] checking openssh-server package"
dpkg -s openssh-server >/dev/null

echo "[validate] checking ssh service enabled"
[[ "$(systemctl is-enabled ssh)" == "enabled" ]]

echo "[validate] checking claw user and sudo package/group"
dpkg -s sudo >/dev/null
getent passwd claw >/dev/null
getent group sudo | grep -Eq "(^|,)claw(,|$)"
claw_groups="$(su - claw -c "id -nG")"
[[ " $claw_groups " == *" sudo "* ]]

echo "[validate] checking node major version >= 22"
node_major="$(node -v | sed -E "s/^v([0-9]+).*/\1/")"
[[ "$node_major" =~ ^[0-9]+$ ]]
(( node_major >= 22 ))

echo "[validate] checking openclaw CLI"
[[ "$(command -v openclaw)" == "/usr/local/bin/openclaw" ]]
/usr/local/bin/openclaw --help >/dev/null

echo "[validate] checking /etc/openclaw/openclaw.env"
test -f /etc/openclaw/openclaw.env
grep -Fx "OPENCLAW_GATEWAY_BIND=127.0.0.1" /etc/openclaw/openclaw.env
grep -Fx "OPENCLAW_GATEWAY_PORT=18789" /etc/openclaw/openclaw.env

echo "[validate] checking openclaw service present"
systemctl cat openclaw.service >/dev/null
if systemctl list-unit-files | grep -q "^openclaw\.service"; then
  [[ "$(systemctl is-enabled openclaw.service)" == "enabled" ]]
fi

echo "[validate] rootfs validation passed"
'

sudo chroot "$MNT_ROOT" /bin/bash -lc "$CHROOT_CHECKS"
