#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="/var/log/clawos-bootstrap.log"
exec >>"$LOG_FILE" 2>&1

echo "[$(date -Is)] clawos-bootstrap start"

mkdir -p /var/lib/clawos /etc/default /etc/clawos

# Branding + version
hostnamectl set-hostname klb-clawos || true
echo "klb-clawos" >/etc/hostname
if ! grep -qE '^127\.0\.1\.1\s+klb-clawos(\s|$)' /etc/hosts 2>/dev/null; then
  sed -i '/^127\.0\.1\.1\s/d' /etc/hosts 2>/dev/null || true
  echo '127.0.1.1 klb-clawos' >>/etc/hosts || true
fi
echo "v0.1.20-beta4" >/etc/clawos/version

cat >/etc/issue <<'EOF'
ClawOS • Made by KLB Groups
Version: v0.1.20-beta4
Repo: https://github.com/TheRealKlobow/ClawOS
Site: http://clawos.klbgroups.com (coming soon)
EOF

PRIMARY_IP="$(hostname -I | awk '{print $1}')"
TARGET_USER="claw"
TARGET_UID="$(id -u "$TARGET_USER" 2>/dev/null || echo "")"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
TARGET_HOME="${TARGET_HOME:-/home/$TARGET_USER}"
USER_SERVICE_FILE="$TARGET_HOME/.config/systemd/user/openclaw-gateway.service"

run_as_user() {
  sudo -u "$TARGET_USER" -H "$@"
}

run_as_user_bus() {
  local uid runtime bus
  uid="$(id -u "$TARGET_USER")"
  runtime="/run/user/${uid}"
  bus="unix:path=${runtime}/bus"
  sudo -u "$TARGET_USER" -H env XDG_RUNTIME_DIR="$runtime" DBUS_SESSION_BUS_ADDRESS="$bus" "$@"
}

ensure_user_service_path() {
  local path_line="Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
  if [[ -f "$USER_SERVICE_FILE" ]] && ! grep -q '^Environment=PATH=' "$USER_SERVICE_FILE"; then
    python3 - <<'PY' "$USER_SERVICE_FILE" "$path_line"
import sys
p, line = sys.argv[1], sys.argv[2]
with open(p, 'r', encoding='utf-8') as f:
    txt = f.read()
if '[Service]\n' in txt:
    txt = txt.replace('[Service]\n', '[Service]\n' + line + '\n', 1)
else:
    txt += '\n[Service]\n' + line + '\n'
with open(p, 'w', encoding='utf-8') as f:
    f.write(txt)
PY
    chown "$TARGET_USER":"$TARGET_USER" "$USER_SERVICE_FILE" || true
  fi
}

if [[ ! -f /etc/clawos/clawos.env ]]; then
  cat >/etc/clawos/clawos.env <<'EOF'
AUTO_UPDATE=false
EOF
fi

# OpenClaw CLI must be pre-baked during image build (no first-boot install)
if ! command -v openclaw >/dev/null 2>&1; then
  echo "openclaw binary missing; image build provisioning incomplete"
  exit 1
fi

# Provision env file from template if not present
if [[ ! -f /etc/default/openclaw-gateway ]]; then
  install -m 600 /opt/clawos/templates/openclaw.env.template /etc/default/openclaw-gateway
fi

# Load env values when present
set -a
[[ -f /etc/default/openclaw-gateway ]] && source /etc/default/openclaw-gateway
set +a

GATEWAY_PORT="${OPENCLAW_GATEWAY_PORT:-18789}"
GATEWAY_BIND_RAW="${OPENCLAW_GATEWAY_BIND:-loopback}"
LAN_HTTP_MODE="${OPENCLAW_LAN_HTTP_MODE:-false}"

if ! [[ "$GATEWAY_PORT" =~ ^[0-9]+$ ]] || (( GATEWAY_PORT < 1 || GATEWAY_PORT > 65535 )); then
  echo "[WARN] invalid OPENCLAW_GATEWAY_PORT='$GATEWAY_PORT'; forcing 18789"
  GATEWAY_PORT=18789
fi

case "$GATEWAY_BIND_RAW" in
  loopback|127.0.0.1|localhost)
    GATEWAY_BIND="127.0.0.1"
    LAN_MODE="off"
    ;;
  lan|0.0.0.0)
    GATEWAY_BIND="0.0.0.0"
    LAN_MODE="on"
    ;;
  *)
    GATEWAY_BIND="$GATEWAY_BIND_RAW"
    LAN_MODE="on"
    ;;
esac

# Port conflict diagnostics + suggestion
if ss -ltn "( sport = :$GATEWAY_PORT )" | tail -n +2 | grep -q .; then
  NEXT_FREE="$GATEWAY_PORT"
  for p in $(seq $((GATEWAY_PORT + 1)) $((GATEWAY_PORT + 20))); do
    if ! ss -ltn "( sport = :$p )" | tail -n +2 | grep -q .; then
      NEXT_FREE="$p"
      break
    fi
  done
  echo "[ERROR] Port already in use: $GATEWAY_PORT"
  echo "[FIX] Check listener: sudo ss -ltnp | grep :$GATEWAY_PORT"
  if [[ "$NEXT_FREE" != "$GATEWAY_PORT" ]]; then
    echo "[FIX] Suggested next free port: $NEXT_FREE"
    sed -i "s/^OPENCLAW_GATEWAY_PORT=.*/OPENCLAW_GATEWAY_PORT=$NEXT_FREE/" /etc/default/openclaw-gateway || true
    GATEWAY_PORT="$NEXT_FREE"
    echo "[FIX] Auto-updated /etc/default/openclaw-gateway with OPENCLAW_GATEWAY_PORT=$GATEWAY_PORT"
  fi
fi

# Apply LAN config: DHCP default, optional static override
if [[ "${NETWORK_STATIC_ENABLED:-false}" == "true" ]]; then
  : "${NETWORK_STATIC_ADDRESS:?NETWORK_STATIC_ADDRESS required when static enabled}"
  : "${NETWORK_STATIC_GATEWAY:?NETWORK_STATIC_GATEWAY required when static enabled}"
  : "${NETWORK_STATIC_DNS:?NETWORK_STATIC_DNS required when static enabled}"
  cat >/etc/netplan/60-clawos.yaml <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: false
      dhcp6: false
      addresses: ["${NETWORK_STATIC_ADDRESS}"]
      routes:
        - to: default
          via: ${NETWORK_STATIC_GATEWAY}
      nameservers:
        addresses: [${NETWORK_STATIC_DNS}]
EOF
else
  cp /opt/clawos/templates/network.template.yaml /etc/netplan/60-clawos.yaml
fi
netplan generate || true

# Ensure SSH stays enabled for headless management
systemctl enable ssh || true

# Keep gateway env explicit + consistent
{
  echo "OPENCLAW_GATEWAY_PORT=$GATEWAY_PORT"
  echo "OPENCLAW_GATEWAY_BIND=$GATEWAY_BIND_RAW"
  grep -E '^OPENCLAW_GATEWAY_TOKEN=' /etc/default/openclaw-gateway || echo "OPENCLAW_GATEWAY_TOKEN="
  echo "OPENCLAW_LAN_HTTP_MODE=$LAN_HTTP_MODE"
} >/etc/default/openclaw-gateway
chmod 600 /etc/default/openclaw-gateway

ALLOWED_ORIGINS_STATUS="OK"
if [[ "$LAN_MODE" == "on" ]]; then
  ORIGINS_JSON="[\"http://${PRIMARY_IP}:${GATEWAY_PORT}\",\"http://127.0.0.1:${GATEWAY_PORT}\",\"http://localhost:${GATEWAY_PORT}\"]"
  if /usr/local/bin/clawos-fix-origin.sh >/dev/null 2>&1; then
    ALLOWED_ORIGINS_STATUS="OK"
  else
    ALLOWED_ORIGINS_STATUS="needs update"
    echo "[ERROR] What happened: could not auto-apply Control UI allowed origins"
    echo "[WHY] Likely cause: gateway config write failed during bootstrap"
    echo "[FIX] Run: sudo /usr/local/bin/clawos-fix-origin.sh"
    echo "[FIX] Manual fallback: openclaw config set gateway.controlUi.allowedOrigins '$ORIGINS_JSON'"
  fi

  if [[ "$LAN_HTTP_MODE" == "true" ]]; then
    openclaw config set gateway.controlUi.allowInsecureAuth true >/dev/null 2>&1 || true
    openclaw config set gateway.controlUi.dangerouslyDisableDeviceAuth true >/dev/null 2>&1 || true
    echo "[WARN] LAN HTTP mode enabled. This is not secure on public networks."
  fi
fi

CONTROL_UI_URL="http://${PRIMARY_IP}:${GATEWAY_PORT}/"
WS_HOST="$PRIMARY_IP"
if [[ "$LAN_MODE" == "off" ]]; then
  CONTROL_UI_URL="http://127.0.0.1:${GATEWAY_PORT}/"
  WS_HOST="127.0.0.1"
fi
WS_URL="ws://${WS_HOST}:${GATEWAY_PORT}"

# Enable and start OpenClaw gateway in user-service mode (matches `openclaw gateway status`).
systemctl daemon-reload
systemctl disable --now openclaw.service >/dev/null 2>&1 || true
systemctl disable --now openclaw-gateway.service >/dev/null 2>&1 || true

if [[ -n "$TARGET_UID" ]]; then
  loginctl enable-linger "$TARGET_USER" >/dev/null 2>&1 || true
  loginctl start-user "$TARGET_USER" >/dev/null 2>&1 || true
  run_as_user openclaw gateway install >/dev/null 2>&1 || true
  ensure_user_service_path

  SERVICE_MODE="user"
  if run_as_user_bus systemctl --user daemon-reload >/dev/null 2>&1; then
    run_as_user openclaw doctor --repair --non-interactive >/dev/null 2>&1 || true
    run_as_user_bus openclaw gateway start >/dev/null 2>&1 || true
  else
    SERVICE_MODE="system"
    systemctl enable openclaw-gateway.service >/dev/null 2>&1 || true
    systemctl restart openclaw-gateway.service
  fi

  READY=0
  for _ in $(seq 1 20); do
    STATUS_OUT="$(run_as_user openclaw gateway status 2>&1 || true)"
    if echo "$STATUS_OUT" | grep -Eiq "RPC probe:\s*(ok|healthy|pass)|Runtime:\s*running"; then
      READY=1
      break
    fi
    sleep 1
  done
  if [[ "$READY" -ne 1 ]]; then
    echo "[ERROR] bootstrap gateway health check failed (mode=$SERVICE_MODE)"
    run_as_user openclaw gateway status || true
    run_as_user_bus journalctl --user -u openclaw-gateway.service -n 120 --no-pager || true
    journalctl -u openclaw-gateway.service -n 120 --no-pager || true
  fi
fi

cat >/etc/motd <<EOF
ClawOS • Made by KLB Groups
Repo: https://github.com/TheRealKlobow/ClawOS
Site: http://clawos.klbgroups.com (coming soon)
Device: $(hostname)
IP: ${PRIMARY_IP}

Connection Summary
- Gateway bind: ${GATEWAY_BIND_RAW}
- Gateway port: ${GATEWAY_PORT}
- Control UI URL: ${CONTROL_UI_URL}
- WebSocket URL: ${WS_URL}
- LAN mode: ${LAN_MODE}
- Allowed origins: ${ALLOWED_ORIGINS_STATUS}

If origin mismatch appears, run:
openclaw config set gateway.controlUi.allowedOrigins '["http://${PRIMARY_IP}:${GATEWAY_PORT}","http://127.0.0.1:${GATEWAY_PORT}","http://localhost:${GATEWAY_PORT}"]'

Guided setup (name/token/port/LAN):
clawos setup
EOF

touch /var/lib/clawos/bootstrap.done
echo "[$(date -Is)] clawos-bootstrap complete"