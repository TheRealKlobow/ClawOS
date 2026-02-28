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

OPENCLAW_REPO_URL="${OPENCLAW_REPO_URL:-https://github.com/openclaw/openclaw.git}"
: "${OPENCLAW_REF:?ERROR: OPENCLAW_REF must be set (tag or commit)}"
: "${PNPM_VERSION:=9.15.4}"

"${CHROOT_PREFIX[@]}" /usr/bin/env OPENCLAW_REPO_URL="$OPENCLAW_REPO_URL" OPENCLAW_REF="$OPENCLAW_REF" PNPM_VERSION="$PNPM_VERSION" bash -lc '
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# Recover from interrupted package state if present
if [[ -f /var/lib/dpkg/lock-frontend || -f /var/lib/dpkg/lock ]]; then
  rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock || true
fi
dpkg --configure -a || true
apt-get -f install -y || true

apt-get update
apt-get install -y --no-install-recommends git curl ca-certificates python3 make g++

command -v node >/dev/null 2>&1 || { echo "ERROR: node not present; run provision-runtime first" >&2; exit 1; }
command -v corepack >/dev/null 2>&1 || { echo "ERROR: corepack not present; run provision-runtime first" >&2; exit 1; }
corepack enable
corepack prepare "pnpm@${PNPM_VERSION}" --activate
command -v pnpm >/dev/null 2>&1 || { echo "ERROR: pnpm not available" >&2; exit 1; }

if id claw >/dev/null 2>&1; then
  usermod -aG sudo claw || true
else
  useradd -m -s /bin/bash -G sudo claw
fi

mkdir -p /opt
rm -rf /opt/openclaw
git clone "$OPENCLAW_REPO_URL" /opt/openclaw

cd /opt/openclaw
git fetch --all --tags --prune
git checkout "$OPENCLAW_REF"
pnpm install --frozen-lockfile || pnpm install
pnpm build

if [[ -f /opt/openclaw/dist/entry.mjs || -f /opt/openclaw/dist/entry.js ]]; then
  :
else
  echo "ERROR: OpenClaw build output missing dist entry" >&2
  exit 1
fi

if [[ -f /opt/openclaw/dist/control-ui/index.html ]]; then
  :
elif compgen -G '/opt/openclaw/dist/control-ui-assets-*.js' >/dev/null; then
  :
else
  mkdir -p /opt/openclaw/dist/control-ui
  cat >/opt/openclaw/dist/control-ui/index.html <<'EOF'
<!doctype html>
<html><head><meta charset="utf-8"><title>Control UI assets missing</title></head>
<body style="font-family: sans-serif; max-width: 720px; margin: 40px auto; line-height: 1.5;">
<h1>Control UI assets are missing</h1>
<p>This image/build is broken: no Control UI artifact was produced in <code>/opt/openclaw/dist</code>.</p>
<p>Fix (builder host):</p>
<pre>cd /opt/openclaw
pnpm install
pnpm build
ls -1 /opt/openclaw/dist/control-ui/index.html /opt/openclaw/dist/control-ui-assets-*.js</pre>
</body></html>
EOF
  echo "ERROR: missing Control UI artifacts after build (/opt/openclaw/dist/control-ui/index.html or /opt/openclaw/dist/control-ui-assets-*.js)" >&2
  exit 1
fi

if [[ -f /opt/openclaw/openclaw.mjs ]]; then
  chmod +x /opt/openclaw/openclaw.mjs
  ln -sf /opt/openclaw/openclaw.mjs /usr/local/bin/openclaw
else
  echo "ERROR: /opt/openclaw/openclaw.mjs missing" >&2
  exit 1
fi

REF_RESOLVED="$(git rev-parse --short HEAD)"
REF_NAME="$(git symbolic-ref --short -q HEAD || git describe --tags --exact-match 2>/dev/null || echo detached)"
BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
mkdir -p /etc/openclaw /etc/clawos
cat >/etc/openclaw/version <<EOF
Commit: ${REF_RESOLVED}
Ref: ${REF_NAME}
PinnedRef: ${OPENCLAW_REF}
BuildDate: ${BUILD_DATE}
EOF
echo "${OPENCLAW_REF}" >/etc/clawos/openclaw-ref

pnpm prune --prod || true

chown -R claw:claw /opt/openclaw

dpkg --configure -a
apt-get -f install -y
apt-get clean
rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/* /tmp/*
chown -R claw:claw /opt/openclaw
if find /opt/openclaw -xdev -uid 0 -print -quit | grep -q .; then
  echo "ERROR: root-owned files remain in /opt/openclaw" >&2
  exit 1
fi
'

echo "Installed OpenClaw source into /opt/openclaw"
