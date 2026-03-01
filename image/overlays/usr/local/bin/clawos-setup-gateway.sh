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
ROOT_CFG_DIR="/root/.openclaw"
ROOT_CFG_FILE="$ROOT_CFG_DIR/openclaw.json"

fail_setup() {
  local reason="$1"
  echo "SETUP_RESULT: FAIL (reason=${reason})"
  exit 1
}

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

write_cfg_json() {
  local file="$1"
  local esc_token
  esc_token="${TOKEN//\\/\\\\}"
  esc_token="${esc_token//\"/\\\"}"
  mkdir -p "$(dirname "$file")"
  cat > "$file" <<EOF
{
  "gateway": {
    "mode": "local",
    "bind": "${BIND}",
    "port": ${PORT},
    "auth": {
      "mode": "token",
      "token": "${esc_token}"
    },
    "remote": {
      "token": "${esc_token}"
    },
    "controlUi": {
      "allowedOrigins": ${ORIGINS_JSON}
    }
  }
}
EOF
}

assert_cfg_invariants() {
  python3 - <<'PY' "$USER_CFG_FILE" "$ROOT_CFG_FILE"
import json,sys
u,r=sys.argv[1],sys.argv[2]

def load(p):
    with open(p,'r',encoding='utf-8') as f:
        return json.load(f)

def tok(cfg):
    g=cfg.get('gateway',{})
    a=((g.get('auth') or {}).get('token'))
    t=((g.get('remote') or {}).get('token'))
    return a,t

def origins(cfg):
    g=cfg.get('gateway',{})
    cu=(g.get('controlUi') or {})
    return cu.get('allowedOrigins')

for p in (u,r):
    try:
        cfg=load(p)
    except Exception:
        print("Root/user config drift")
        raise SystemExit(10)
    a,t=tok(cfg)
    if not a or not t:
        print("Root config token mismatch")
        raise SystemExit(11)
    if a!=t:
        print("Root config token mismatch")
        raise SystemExit(12)

ucfg=load(u); rcfg=load(r)
ua,ut=tok(ucfg); ra,rt=tok(rcfg)
if ua!=ra or ut!=rt:
    print("Root/user config drift")
    raise SystemExit(13)
uo=origins(ucfg); ro=origins(rcfg)
if not isinstance(uo, list) or not isinstance(ro, list) or not uo or not ro:
    print("Root/user config drift")
    raise SystemExit(14)
if uo!=ro:
    print("Root/user config drift")
    raise SystemExit(15)
print("OK")
PY
}

check_invariants_or_fail() {
  local out
  out="$(assert_cfg_invariants 2>&1 || true)"
  if echo "$out" | grep -q "OK"; then
    return 0
  fi
  if echo "$out" | grep -qi "token"; then
    fail_setup "Root config token mismatch"
  fi
  fail_setup "Root/user config drift"
}

stop_and_free_port() {
  local p="$1"
  run_as_user_bus systemctl --user stop openclaw-gateway.service >/dev/null 2>&1 || true
  run_as_user openclaw gateway stop >/dev/null 2>&1 || true
  systemctl stop openclaw-gateway.service >/dev/null 2>&1 || true

  local pids
  pids="$(ss -ltnp 2>/dev/null | awk -v p=":${p}" '$4 ~ p {print $NF}' | sed -n 's/.*pid=\([0-9]\+\).*/\1/p' | sort -u)"
  if [[ -n "$pids" ]]; then
    kill -9 $pids >/dev/null 2>&1 || true
  fi

  if ss -ltn "( sport = :${p} )" | tail -n +2 | grep -q .; then
    fail_setup "Port still bound after stop"
  fi
}

is_healthy() {
  local s
  s="$(run_as_user openclaw gateway status 2>&1 || true)"
  echo "$s" | grep -Eiq "RPC probe:\s*(ok|healthy|pass)|Runtime:\s*running"
}

print_fail_logs() {
  local mode="$1"
  if [[ "$mode" == "user" ]]; then
    run_as_user_bus journalctl --user -u openclaw-gateway.service -n 50 --no-pager || true
  else
    journalctl -u openclaw-gateway.service -n 50 --no-pager || true
  fi
}

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
  for p in $(seq $((PORT + 1)) $((PORT + 30))); do
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

PRIMARY_IP="$(hostname -I | awk '{print $1}')"
ORIGINS_JSON="[\"http://${PRIMARY_IP:-127.0.0.1}:${PORT}\",\"http://127.0.0.1:${PORT}\",\"http://localhost:${PORT}\"]"

cat > "$CFG" <<EOF
OPENCLAW_GATEWAY_BIND=${BIND}
OPENCLAW_GATEWAY_PORT=${PORT}
OPENCLAW_GATEWAY_TOKEN=${TOKEN}
OPENCLAW_LAN_HTTP_MODE=${LAN_HTTP_MODE}
EOF
chmod 600 "$CFG"

# Always overwrite both configs.
write_cfg_json "$USER_CFG_FILE"
write_cfg_json "$ROOT_CFG_FILE"
chown -R "$TARGET_USER":"$TARGET_USER" "$USER_CFG_DIR"
chmod 700 "$USER_CFG_DIR"
chmod 600 "$USER_CFG_FILE"
chmod 700 "$ROOT_CFG_DIR"
chmod 600 "$ROOT_CFG_FILE"

# Sync via CLI too (keeps ancillary keys aligned).
run_as_user openclaw config set gateway.mode local >/dev/null 2>&1 || true
run_as_user openclaw config set gateway.bind "$BIND" >/dev/null 2>&1 || true
run_as_user openclaw config set gateway.port "$PORT" >/dev/null 2>&1 || true
run_as_user openclaw config set gateway.auth.mode token >/dev/null 2>&1 || true
run_as_user openclaw config set gateway.auth.token "$TOKEN" >/dev/null 2>&1 || true
run_as_user openclaw config set gateway.remote.token "$TOKEN" >/dev/null 2>&1 || true
run_as_user openclaw config unset gateway.remote.url >/dev/null 2>&1 || true

openclaw config set gateway.mode local >/dev/null 2>&1 || true
openclaw config set gateway.bind "$BIND" >/dev/null 2>&1 || true
openclaw config set gateway.port "$PORT" >/dev/null 2>&1 || true
openclaw config set gateway.auth.mode token >/dev/null 2>&1 || true
openclaw config set gateway.auth.token "$TOKEN" >/dev/null 2>&1 || true
openclaw config set gateway.remote.token "$TOKEN" >/dev/null 2>&1 || true
openclaw config unset gateway.remote.url >/dev/null 2>&1 || true

check_invariants_or_fail

run_as_user openclaw config set gateway.controlUi.allowedOrigins "$ORIGINS_JSON" >/dev/null 2>&1 || true
openclaw config set gateway.controlUi.allowedOrigins "$ORIGINS_JSON" >/dev/null 2>&1 || true

loginctl enable-linger "$TARGET_USER" >/dev/null 2>&1 || true
loginctl start-user "$TARGET_USER" >/dev/null 2>&1 || true

SERVICE_MODE="user"
stop_and_free_port "$PORT"

if run_as_user_bus systemctl --user daemon-reload >/dev/null 2>&1; then
  run_as_user openclaw gateway install >/dev/null 2>&1 || true
  run_as_user_bus openclaw gateway start >/dev/null 2>&1 || true
fi

READY=0
for _ in $(seq 1 12); do
  if is_healthy; then READY=1; break; fi
  sleep 1
done

if [[ "$READY" -ne 1 ]]; then
  SERVICE_MODE="system"
  stop_and_free_port "$PORT"

  # Re-read + validate root config before system start.
  check_invariants_or_fail

  systemctl daemon-reload
  systemctl enable openclaw-gateway.service >/dev/null 2>&1 || true
  systemctl restart openclaw-gateway.service

  for _ in $(seq 1 12); do
    if is_healthy; then READY=1; break; fi
    sleep 1
  done
fi

if [[ "$READY" -ne 1 ]]; then
  print_fail_logs "$SERVICE_MODE"
  fail_setup "Gateway unhealthy after start"
fi

token_prefix="${TOKEN:0:6}"
echo "SETUP_RESULT: PASS (mode=${SERVICE_MODE} port=${PORT} token=${token_prefix})"
