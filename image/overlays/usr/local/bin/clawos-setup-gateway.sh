#!/usr/bin/env bash
set -euo pipefail

CFG="/etc/default/openclaw-gateway"
mkdir -p /etc/default
[[ -f "$CFG" ]] || touch "$CFG"

echo "ClawOS • Made by KLB Groups"
echo "Gateway guided setup"
echo

read -rp "Device name [klb-clawos]: " DEVICE_NAME
DEVICE_NAME="${DEVICE_NAME:-klb-clawos}"

read -rp "Gateway token [testtokenpi1234]: " TOKEN
TOKEN="${TOKEN:-testtokenpi1234}"

read -rp "Gateway port [18790]: " PORT
PORT="${PORT:-18790}"
if ! [[ "$PORT" =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
  echo "Invalid port. Use 1..65535."
  exit 1
fi

if ss -ltn "( sport = :${PORT} )" | tail -n +2 | grep -q .; then
  echo "Port ${PORT} already in use."
  for p in $(seq $((PORT + 1)) $((PORT + 20))); do
    if ! ss -ltn "( sport = :${p} )" | tail -n +2 | grep -q .; then
      echo "Suggested free port: ${p}"
      read -rp "Use ${p}? [Y/n]: " yn
      yn="${yn:-Y}"
      if [[ "$yn" =~ ^[Yy]$ ]]; then
        PORT="$p"
      fi
      break
    fi
  done
fi

read -rp "Enable LAN mode? [Y/n]: " LAN_ON
LAN_ON="${LAN_ON:-Y}"
if [[ "$LAN_ON" =~ ^[Yy]$ ]]; then
  BIND="lan"
  LAN_HTTP_MODE="true"
else
  BIND="loopback"
  LAN_HTTP_MODE="false"
fi

cat > "$CFG" <<EOF
OPENCLAW_GATEWAY_BIND=${BIND}
OPENCLAW_GATEWAY_PORT=${PORT}
OPENCLAW_GATEWAY_TOKEN=${TOKEN}
OPENCLAW_LAN_HTTP_MODE=${LAN_HTTP_MODE}
EOF
chmod 600 "$CFG"

hostnamectl set-hostname "$DEVICE_NAME" || true
echo "$DEVICE_NAME" >/etc/hostname

PRIMARY_IP="$(hostname -I | awk '{print $1}')"
if [[ -n "${PRIMARY_IP}" ]]; then
  ORIGINS_JSON="[\"http://${PRIMARY_IP}:${PORT}\",\"http://127.0.0.1:${PORT}\",\"http://localhost:${PORT}\"]"
  openclaw config set gateway.controlUi.allowedOrigins "$ORIGINS_JSON" >/dev/null 2>&1 || true
fi

systemctl daemon-reload
systemctl enable openclaw-gateway.service >/dev/null 2>&1 || true
systemctl restart openclaw-gateway.service

echo
echo "Connection Summary"
echo "- Device: ${DEVICE_NAME}"
echo "- Bind: ${BIND}"
echo "- Port: ${PORT}"
echo "- UI: http://${PRIMARY_IP:-127.0.0.1}:${PORT}/"
echo "- WS: ws://${PRIMARY_IP:-127.0.0.1}:${PORT}"
echo "- Token: ${TOKEN}"
if [[ "$LAN_HTTP_MODE" == "true" ]]; then
  echo "- Warning: LAN HTTP mode enabled (not secure on public networks)"
fi
