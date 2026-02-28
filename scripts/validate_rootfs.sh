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
KPARTX_USED=0

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
  if [[ "$KPARTX_USED" -eq 1 && -n "$LOOP_DEV" ]]; then
    sudo kpartx -d "$LOOP_DEV" 2>/dev/null || true
  fi
  if [[ -n "$LOOP_DEV" ]]; then
    sudo losetup -d "$LOOP_DEV" 2>/dev/null || true
  fi
}
trap cleanup EXIT

LOOP_DEV="$(sudo losetup --find --show --partscan "$IMAGE_PATH")"
loop_base="$(basename "$LOOP_DEV")"

# Prefer direct p2 path when available.
if [[ -b "${LOOP_DEV}p2" ]]; then
  ROOT_PART="${LOOP_DEV}p2"
fi

# Otherwise, discover partitions via lsblk and prefer PARTLABEL rootfs, then 2nd partition, then last.
if [[ -z "$ROOT_PART" ]]; then
  mapfile -t loop_parts < <(lsblk -lnpo NAME,TYPE,PKNAME | awk -v pk="$loop_base" '$2=="part" && $3==pk {print $1}')
  if [[ ${#loop_parts[@]} -eq 0 ]] && command -v kpartx >/dev/null 2>&1; then
    sudo kpartx -av "$LOOP_DEV" >/dev/null
    KPARTX_USED=1
    sleep 1
    mapfile -t loop_parts < <(lsblk -lnpo NAME,TYPE,PKNAME | awk -v pk="$loop_base" '$2=="part" && $3==pk {print $1}')
  fi

  if [[ ${#loop_parts[@]} -gt 0 ]]; then
    ROOT_PART="$(lsblk -lnpo NAME,PARTLABEL "${loop_parts[@]}" | awk '$2 ~ /rootfs|ROOTFS/ {print $1; exit}')"
    if [[ -z "$ROOT_PART" ]]; then
      if [[ ${#loop_parts[@]} -ge 2 ]]; then
        ROOT_PART="${loop_parts[1]}"
      else
        ROOT_PART="${loop_parts[-1]}"
      fi
    fi
  fi
fi

[[ -n "$ROOT_PART" && -b "$ROOT_PART" ]] || {
  echo "ERROR: failed to locate root partition on $LOOP_DEV" >&2
  lsblk -lnpo NAME,TYPE,PKNAME,PARTLABEL "$LOOP_DEV" || true
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

echo "[validate] checking ssh runtime directory configuration"
if ! grep -Rqs "^RuntimeDirectory=sshd$" /etc/systemd/system/ssh.service.d /lib/systemd/system/ssh.service /usr/lib/systemd/system/ssh.service 2>/dev/null; then
  test -f /etc/tmpfiles.d/sshd.conf
fi

echo "[validate] checking no conflicting ssh.socket enablement"
if systemctl list-unit-files | grep -q "^ssh\\.socket"; then
  socket_state="$(systemctl is-enabled ssh.socket || true)"
  case "$socket_state" in
    masked|disabled|static) ;;
    *)
      echo "ssh.socket must not be enabled (state=$socket_state)" >&2
      exit 1
      ;;
  esac
fi
if [[ -L /etc/systemd/system/ssh.socket ]]; then
  socket_target="$(readlink /etc/systemd/system/ssh.socket)"
  [[ "$socket_target" == "/dev/null" ]]
elif [[ -e /etc/systemd/system/sockets.target.wants/ssh.socket ]]; then
  echo "ssh.socket is enabled via sockets.target.wants" >&2
  exit 1
fi

echo "[validate] checking no dropbear conflict"
if dpkg -s dropbear >/dev/null 2>&1; then
  echo "dropbear must not be installed" >&2
  exit 1
fi

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
