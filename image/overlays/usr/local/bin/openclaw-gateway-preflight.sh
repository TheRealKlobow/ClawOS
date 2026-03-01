#!/usr/bin/env bash
set -euo pipefail

OPENCLAW_BIN="$(command -v openclaw || true)"
if [[ -z "$OPENCLAW_BIN" || ! -x "$OPENCLAW_BIN" ]]; then
  echo "[ERROR] What happened: openclaw binary is missing or not executable"
  echo "[WHY] Likely cause: image provisioning did not finish correctly"
  echo "[FIX] Verify binary: command -v openclaw && ls -l \"$(command -v openclaw)\""
  echo "[FIX] Reinstall runtime/image or run guided setup again"
  exit 1
fi

PORT="${OPENCLAW_GATEWAY_PORT:-18790}"

if ! [[ "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
  echo "[ERROR] What happened: invalid OPENCLAW_GATEWAY_PORT='$PORT'"
  echo "[WHY] Likely cause: port must be numeric in range 1..65535"
  echo "[FIX] Set a valid port in /etc/default/openclaw-gateway, e.g.:"
  echo "      sudo sed -i 's/^OPENCLAW_GATEWAY_PORT=.*/OPENCLAW_GATEWAY_PORT=18790/' /etc/default/openclaw-gateway"
  exit 1
fi

if ss -ltn "( sport = :${PORT} )" | tail -n +2 | grep -q .; then
  echo "[ERROR] What happened: port already in use (${PORT})"
  echo "[WHY] Likely cause: another process is already listening on this port"
  echo "[FIX] Check listener: sudo ss -ltnp | grep :${PORT}"
  echo "[FIX] Choose another port: sudo sed -i 's/^OPENCLAW_GATEWAY_PORT=.*/OPENCLAW_GATEWAY_PORT=18800/' /etc/default/openclaw-gateway"
  echo "[FIX] Restart service: sudo systemctl restart openclaw-gateway.service"
  exit 1
fi
