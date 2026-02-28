#!/usr/bin/env bash
set -euo pipefail

CFG="$HOME/.openclaw/openclaw.json"
TOKEN=""
PORT=""
BIND=""

if [[ -f "$CFG" ]]; then
  TOKEN="$(python3 - <<'PY' "$CFG"
import json,sys
c=json.load(open(sys.argv[1],'r',encoding='utf-8'))
g=c.get('gateway',{})
print(((g.get('auth') or {}).get('token')) or '')
PY
)"
fi

if [[ -f /etc/default/openclaw-gateway ]]; then
  # shellcheck disable=SC1091
  source /etc/default/openclaw-gateway || true
  TOKEN="${OPENCLAW_GATEWAY_TOKEN:-$TOKEN}"
  PORT="${OPENCLAW_GATEWAY_PORT:-18790}"
  BIND="${OPENCLAW_GATEWAY_BIND:-lan}"
fi

[[ -n "$TOKEN" ]] || TOKEN="testtokenpi1234"
[[ -n "$PORT" ]] || PORT="18790"
[[ -n "$BIND" ]] || BIND="lan"

openclaw config set gateway.mode local >/dev/null || true
openclaw config set gateway.bind "$BIND" >/dev/null || true
openclaw config set gateway.port "$PORT" >/dev/null || true
openclaw config set gateway.auth.mode token >/dev/null || true
openclaw config set gateway.auth.token "$TOKEN" >/dev/null || true
openclaw config set gateway.remote.token "$TOKEN" >/dev/null || true
openclaw config unset gateway.remote.url >/dev/null || true

# Heal hostname resolution drift that causes sudo "unable to resolve host" warnings.
H="$(hostname 2>/dev/null || true)"
if [[ -n "$H" ]] && [[ -w /etc/hosts ]]; then
  if ! grep -qE "^127\.0\.1\.1\s+${H}(\s|$)" /etc/hosts; then
    sed -i '/^127\.0\.1\.1\s/d' /etc/hosts || true
    echo "127.0.1.1 ${H}" >>/etc/hosts || true
  fi
fi

openclaw gateway stop >/dev/null 2>&1 || true
pkill -f "openclaw.*gateway" >/dev/null 2>&1 || true

openclaw gateway install >/dev/null 2>&1 || true
systemctl --user daemon-reload || true
systemctl --user enable --now openclaw-gateway.service || true

echo "[OK] ClawOS doctor finished"
echo "- bind=$BIND"
echo "- port=$PORT"
echo "- token synced (auth + remote)"
