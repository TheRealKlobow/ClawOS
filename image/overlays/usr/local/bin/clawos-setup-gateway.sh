#!/usr/bin/env bash
set -euo pipefail

CFG="/etc/default/openclaw-gateway"
mkdir -p /etc/default
[[ -f "$CFG" ]] || touch "$CFG"

TARGET_USER="${SUDO_USER:-claw}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
TARGET_HOME="${TARGET_HOME:-/home/$TARGET_USER}"
USER_CFG_DIR="$TARGET_HOME/.openclaw"
USER_CFG_FILE="$USER_CFG_DIR/openclaw.json"

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

# Keep user CLI/gateway config in sync with system gateway config so
# `openclaw gateway status` reflects the same bind/port/token choices.
mkdir -p "$USER_CFG_DIR"
ESC_TOKEN="${TOKEN//\\/\\\\}"
ESC_TOKEN="${ESC_TOKEN//\"/\\\"}"
cat > "$USER_CFG_FILE" <<EOF
{
  "gateway": {
    "mode": "local",
    "bind": "${BIND}",
    "port": ${PORT},
    "auth": {
      "mode": "token",
      "token": "${ESC_TOKEN}"
    },
    "remote": {
      "token": "${ESC_TOKEN}"
    }
  }
}
EOF
chown -R "$TARGET_USER":"$TARGET_USER" "$USER_CFG_DIR"
chmod 700 "$USER_CFG_DIR"
chmod 600 "$USER_CFG_FILE"

if ! hostnamectl set-hostname "$DEVICE_NAME"; then
  echo "[WARN] Could not set static hostname via hostnamectl. Trying transient hostname..."
  hostnamectl --transient set-hostname "$DEVICE_NAME" >/dev/null 2>&1 || true
fi
if ! echo "$DEVICE_NAME" >/etc/hostname 2>/dev/null; then
  echo "[WARN] Could not write /etc/hostname (read-only or restricted). Continuing with current hostname."
fi
if ! grep -qE "^127\.0\.1\.1\s+${DEVICE_NAME}(\s|$)" /etc/hosts 2>/dev/null; then
  sed -i '/^127\.0\.1\.1\s/d' /etc/hosts 2>/dev/null || true
  echo "127.0.1.1 ${DEVICE_NAME}" >>/etc/hosts 2>/dev/null || true
fi
CURRENT_HOST="$(hostname 2>/dev/null || true)"
if [[ -n "$CURRENT_HOST" ]] && ! grep -qE "^127\.0\.1\.1\s+${CURRENT_HOST}(\s|$)" /etc/hosts 2>/dev/null; then
  echo "127.0.1.1 ${CURRENT_HOST}" >>/etc/hosts 2>/dev/null || true
fi

PRIMARY_IP="$(hostname -I | awk '{print $1}')"
ALLOWED_ORIGINS_STATUS="needs update"
ORIGINS_JSON="[\"http://${PRIMARY_IP:-127.0.0.1}:${PORT}\",\"http://127.0.0.1:${PORT}\",\"http://localhost:${PORT}\"]"
openclaw config unset gateway.remote.url >/dev/null 2>&1 || true
openclaw config set gateway.remote.token "$TOKEN" >/dev/null 2>&1 || true
if openclaw config set gateway.controlUi.allowedOrigins "$ORIGINS_JSON" >/dev/null 2>&1; then
  ALLOWED_ORIGINS_STATUS="OK"
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
echo "- Allowed origins: ${ALLOWED_ORIGINS_STATUS}"
echo "- Synced CLI config: ${USER_CFG_FILE}"
echo "- Repo: https://github.com/TheRealKlobow/ClawOS"
echo "- Site: http://clawos.klbgroups.com (coming soon)"
if [[ "$LAN_HTTP_MODE" == "true" ]]; then
  echo "- Warning: LAN HTTP mode enabled (not secure on public networks)"
fi
echo
if [[ "$ALLOWED_ORIGINS_STATUS" != "OK" ]]; then
  echo "If origin mismatch appears, run:"
  echo "openclaw config set gateway.controlUi.allowedOrigins '${ORIGINS_JSON}'"
fi
