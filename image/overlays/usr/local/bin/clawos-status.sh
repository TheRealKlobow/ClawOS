#!/usr/bin/env bash
set -euo pipefail

openclaw gateway status "$@" || true

CFG="$HOME/.openclaw/openclaw.json"
if [[ ! -f "$CFG" ]]; then
  echo "[WARN] user config missing: $CFG"
  exit 0
fi

python3 - <<'PY' "$CFG"
import json,sys
p=sys.argv[1]
try:
    c=json.load(open(p,'r',encoding='utf-8'))
except Exception as e:
    print(f"[WARN] cannot parse config: {e}")
    raise SystemExit(0)
g=c.get('gateway',{})
a=((g.get('auth') or {}).get('token'))
r=((g.get('remote') or {}).get('token'))
ru=(g.get('remote') or {}).get('url')
if a and r and a!=r:
    print("[WARN] token drift detected: gateway.auth.token != gateway.remote.token")
    print("[FIX] run: clawos doctor")
if ru:
    print(f"[INFO] gateway.remote.url set: {ru}")
    print("[INFO] For local/LAN mode this can be unset to avoid stale remote checks.")
PY

if pgrep -f "openclaw.*gateway" >/dev/null 2>&1; then
  if ! systemctl --user is-active --quiet openclaw-gateway.service; then
    echo "[WARN] manual gateway process detected while user service is not active (mixed mode)."
    echo "[FIX] run: clawos doctor"
  fi
fi
