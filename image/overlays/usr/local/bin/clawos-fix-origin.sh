#!/usr/bin/env bash
set -euo pipefail

CFG="/etc/default/openclaw-gateway"
PORT="18790"
if [[ -f "$CFG" ]]; then
  # shellcheck disable=SC1090
  source "$CFG" || true
fi
PORT="${OPENCLAW_GATEWAY_PORT:-$PORT}"
PRIMARY_IP="$(hostname -I | awk '{print $1}')"
ORIGINS_JSON="[\"http://${PRIMARY_IP:-127.0.0.1}:${PORT}\",\"http://127.0.0.1:${PORT}\",\"http://localhost:${PORT}\"]"

if openclaw config set gateway.controlUi.allowedOrigins "$ORIGINS_JSON" >/dev/null 2>&1; then
  echo "[OK] allowed origins applied"
  echo "[INFO] origin(s): ${ORIGINS_JSON}"
else
  echo "[ERROR] What happened: failed to apply allowed origins"
  echo "[WHY] Likely cause: openclaw config write failed or gateway config path unavailable"
  echo "[FIX] Retry: sudo openclaw config set gateway.controlUi.allowedOrigins '${ORIGINS_JSON}'"
  exit 1
fi
