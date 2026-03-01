#!/usr/bin/env bash
set -euo pipefail

TARGET_USER="${1:-claw}"

echo "[smoke] checking gateway health for user=$TARGET_USER"
if ! id "$TARGET_USER" >/dev/null 2>&1; then
  echo "[fail] user not found: $TARGET_USER"
  exit 1
fi

if ! sudo -u "$TARGET_USER" -H openclaw gateway status > /tmp/clawos-gateway-status.txt 2>&1; then
  cat /tmp/clawos-gateway-status.txt
  echo "[fail] openclaw gateway status command failed"
  exit 1
fi

if ! grep -Eiq "Runtime:\s*running|RPC probe:\s*(ok|healthy|pass)" /tmp/clawos-gateway-status.txt; then
  cat /tmp/clawos-gateway-status.txt
  echo "[fail] gateway not healthy"
  exit 1
fi

echo "[ok] gateway status healthy"
