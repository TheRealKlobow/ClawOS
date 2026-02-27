#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   PI_HOST=pi@clawos.local bash scripts/proof-run-bundle-v0.1.1.sh
# Optional tar bundle:
#   PROOF_TAR=true PI_HOST=pi@clawos.local bash scripts/proof-run-bundle-v0.1.1.sh

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

mkdir -p out/proof out/proof/builder out/proof/artifacts out/proof/pi out/proof/release

run_or_missing() {
  local cmd_name="$1"
  local out_file="$2"
  shift 2
  if command -v "$cmd_name" >/dev/null 2>&1; then
    "$@" >"$out_file" 2>&1 || echo "command failed: $*" >>"$out_file"
  else
    echo "missing: $cmd_name" >"$out_file"
  fi
}

# ---- Builder evidence ----
run_or_missing uname out/proof/builder/uname.txt uname -a
if [[ -f /etc/os-release ]]; then
  cat /etc/os-release > out/proof/builder/os-release.txt
else
  echo "missing: /etc/os-release" > out/proof/builder/os-release.txt
fi

run_or_missing losetup out/proof/builder/losetup-version.txt losetup --version
run_or_missing kpartx out/proof/builder/kpartx-version.txt kpartx -V
run_or_missing mount out/proof/builder/mount-version.txt mount --version
run_or_missing lsblk out/proof/builder/lsblk-version.txt lsblk --version

run_or_missing git out/proof/builder/git-head.txt git rev-parse HEAD
run_or_missing git out/proof/builder/git-status-porcelain.txt git status --porcelain
run_or_missing git out/proof/builder/git-submodule-status.txt git submodule status --recursive
run_or_missing git out/proof/builder/git-tags-points-at-head.txt git tag --points-at HEAD

# ---- Build + release files ----
set -a
source .env
set +a
bash image/build.sh > out/proof/builder/build.log 2>&1
bash scripts/release-image.sh > out/proof/builder/release-script.log 2>&1
bash scripts/pre-release-validate.sh > out/proof/builder/pre-release-validate.log 2>&1

# ---- Artifact evidence ----
if command -v find >/dev/null 2>&1 && find --version 2>/dev/null | grep -qi gnu; then
  find out -maxdepth 3 -type f -printf "%p %s bytes\n" | sort > out/proof/artifacts/out-tree.txt
else
  # portable fallback (no GNU find -printf required)
  python3 - <<'PY' > out/proof/artifacts/out-tree.txt
import os
base='out'
rows=[]
for root,_,files in os.walk(base):
    depth=root[len(base):].count(os.sep)
    if depth>3:
        continue
    for f in files:
        p=os.path.join(root,f)
        try:
            s=os.path.getsize(p)
            rows.append((p,s))
        except OSError:
            pass
for p,s in sorted(rows):
    print(f"{p} {s} bytes")
PY
fi

run_or_missing sha256sum out/proof/artifacts/clawos-pi.img.sha256.txt sha256sum out/clawos-pi.img
run_or_missing sha256sum out/proof/artifacts/clawos-pi.img.xz.sha256.txt sha256sum out/clawos-pi.img.xz
cp out/SHA256SUMS.txt out/proof/artifacts/SHA256SUMS.txt
run_or_missing sha256sum out/proof/artifacts/sha256-verify.txt sha256sum -c out/SHA256SUMS.txt

# ---- Release docs copy ----
cp docs/release-v0.1.1.md out/proof/release/release-v0.1.1.md
cp docs/checklist-v0.1.1-proof.md out/proof/release/checklist-v0.1.1-proof.md
cp docs/release-notes-template.md out/proof/release/release-notes-template.md

# ---- Pi sanity + evidence ----
PI_HOST="${PI_HOST:-}"
if [[ -z "$PI_HOST" ]]; then
  echo "ERROR: PI_HOST is required (example: PI_HOST=pi@clawos.local)" >&2
  exit 1
fi

if ! ssh -o BatchMode=yes -o ConnectTimeout=8 "$PI_HOST" "echo connected" >/dev/null 2>&1; then
  echo "ERROR: cannot reach PI_HOST=$PI_HOST over SSH" >&2
  exit 1
fi

ssh "$PI_HOST" "set -euo pipefail; tr -d '\0' </proc/device-tree/model" > out/proof/pi/device-model.txt
ssh "$PI_HOST" "set -euo pipefail; hostname" > out/proof/pi/hostname.txt
ssh "$PI_HOST" "set -euo pipefail; hostname -I" > out/proof/pi/hostname-I.txt
ssh "$PI_HOST" "set -euo pipefail; ip route" > out/proof/pi/ip-route.txt
ssh "$PI_HOST" "set -euo pipefail; cat /etc/resolv.conf" > out/proof/pi/resolv.conf.txt
ssh "$PI_HOST" "set -euo pipefail; timedatectl" > out/proof/pi/timedatectl.txt

ssh "$PI_HOST" "set -euo pipefail; cat /etc/issue" > out/proof/pi/etc-issue.txt
ssh "$PI_HOST" "set -euo pipefail; cat /etc/motd" > out/proof/pi/etc-motd.txt
ssh "$PI_HOST" "set -euo pipefail; cat /etc/clawos/version" > out/proof/pi/etc-clawos-version.txt
ssh "$PI_HOST" "set -euo pipefail; cat /etc/clawos/clawos.env" > out/proof/pi/etc-clawos-env.txt
ssh "$PI_HOST" "set -euo pipefail; ls -l /var/lib/clawos/bootstrap.done" > out/proof/pi/bootstrap-done.txt

ssh "$PI_HOST" "set -euo pipefail; systemctl status clawos-bootstrap --no-pager" > out/proof/pi/systemctl-clawos-bootstrap.txt
ssh "$PI_HOST" "set -euo pipefail; systemctl status openclaw-gateway --no-pager" > out/proof/pi/systemctl-openclaw-gateway.txt
ssh "$PI_HOST" "set -euo pipefail; journalctl -u openclaw-gateway --no-pager | tail -n 200" > out/proof/pi/journal-openclaw-gateway-tail200.txt
ssh "$PI_HOST" "set -euo pipefail; ss -tulpn | grep ':22\|:18789'" > out/proof/pi/ports-22-18789.txt

ssh "$PI_HOST" "set -euo pipefail; systemctl is-enabled clawos-bootstrap" > out/proof/pi/is-enabled-clawos-bootstrap.txt
ssh "$PI_HOST" "set -euo pipefail; systemctl is-enabled openclaw-gateway" > out/proof/pi/is-enabled-openclaw-gateway.txt
ssh "$PI_HOST" "set -euo pipefail; systemctl is-enabled clawos-update.timer" > out/proof/pi/is-enabled-clawos-update-timer.txt
ssh "$PI_HOST" "set -euo pipefail; systemctl list-timers --all | grep clawos" > out/proof/pi/list-timers-clawos.txt

ssh "$PI_HOST" "set -euo pipefail; systemctl status clawos-update.timer --no-pager" > out/proof/pi/systemctl-clawos-update-timer.txt
ssh "$PI_HOST" "set -euo pipefail; systemctl status clawos-update.service --no-pager || true" > out/proof/pi/systemctl-clawos-update-service.txt
ssh "$PI_HOST" "set -euo pipefail; tail -n 200 /var/log/clawos-bootstrap.log" > out/proof/pi/clawos-bootstrap-log-tail200.txt
ssh "$PI_HOST" "set -euo pipefail; tail -n 200 /var/log/clawos-update.log || true" > out/proof/pi/clawos-update-log-tail200.txt

# Manifest
if command -v find >/dev/null 2>&1 && find --version 2>/dev/null | grep -qi gnu; then
  find out/proof -type f -printf "%p %s bytes\n" | sort > out/proof/MANIFEST.txt
else
  python3 - <<'PY' > out/proof/MANIFEST.txt
import os
base='out/proof'
rows=[]
for root,_,files in os.walk(base):
    for f in files:
        p=os.path.join(root,f)
        try:
            s=os.path.getsize(p)
            rows.append((p,s))
        except OSError:
            pass
for p,s in sorted(rows):
    print(f"{p} {s} bytes")
PY
fi

# Optional tar bundle
if [[ "${PROOF_TAR:-false}" == "true" ]]; then
  tar -czf out/proof-v0.1.1.tar.gz -C out proof
  sha256sum out/proof-v0.1.1.tar.gz > out/proof-v0.1.1.tar.gz.sha256
fi

echo "Proof bundle complete: out/proof/"
if [[ "${PROOF_TAR:-false}" == "true" ]]; then
  echo "Tar bundle: out/proof-v0.1.1.tar.gz"
fi
