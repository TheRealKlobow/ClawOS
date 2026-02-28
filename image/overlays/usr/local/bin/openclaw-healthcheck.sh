#!/usr/bin/env bash
set -euo pipefail

ok=1

echo "== OpenClaw Healthcheck =="

if [[ -d /opt/openclaw ]]; then
  echo "[OK] /opt/openclaw exists"
else
  echo "[FAIL] /opt/openclaw missing"
  ok=0
fi

if command -v node >/dev/null 2>&1; then
  echo "[OK] node: $(command -v node) ($(node -v))"
else
  echo "[FAIL] node missing"
  ok=0
fi

if [[ -f /etc/systemd/system/openclaw.service ]]; then
  echo "[OK] openclaw.service file present"
else
  echo "[FAIL] openclaw.service missing"
  ok=0
fi

enabled_state="$(systemctl is-enabled openclaw.service 2>/dev/null || true)"
active_state="$(systemctl is-active openclaw.service 2>/dev/null || true)"
echo "service enabled: ${enabled_state:-unknown}"
echo "service active: ${active_state:-unknown}"

if [[ "$enabled_state" != "enabled" || "$active_state" != "active" ]]; then
  ok=0
  echo "--- Last 50 openclaw logs ---"
  journalctl -u openclaw --no-pager -n 50 || true
fi

if [[ "$ok" -eq 1 ]]; then
  echo "HEALTHCHECK OK"
  exit 0
fi

echo "HEALTHCHECK FAILED"
exit 1
