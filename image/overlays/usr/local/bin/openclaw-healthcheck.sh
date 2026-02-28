#!/usr/bin/env bash
set -euo pipefail

state=0 # 0 healthy, 1 degraded, 2 failed

echo "== OpenClaw Healthcheck =="

if [[ -d /opt/openclaw ]]; then
  echo "[OK] /opt/openclaw exists"
else
  echo "[FAIL] /opt/openclaw missing"
  state=2
fi

if command -v node >/dev/null 2>&1; then
  echo "[OK] node: $(command -v node) ($(node -v))"
else
  echo "[FAIL] node missing"
  state=2
fi

if command -v pnpm >/dev/null 2>&1; then
  echo "[OK] pnpm: $(command -v pnpm) ($(pnpm -v))"
else
  echo "[WARN] pnpm missing"
  [[ $state -lt 1 ]] && state=1
fi

if [[ -f /opt/openclaw/dist/entry.mjs || -f /opt/openclaw/dist/entry.js ]]; then
  echo "[OK] OpenClaw dist entry exists"
else
  echo "[FAIL] OpenClaw dist entry missing"
  state=2
fi

if [[ -f /etc/openclaw/version ]]; then
  echo "[OK] /etc/openclaw/version present"
  cat /etc/openclaw/version
else
  echo "[FAIL] /etc/openclaw/version missing"
  state=2
fi

expected_ref="$(cat /etc/clawos/openclaw-ref 2>/dev/null || true)"
pinned_ref="$(awk -F': ' '/^PinnedRef:/{print $2}' /etc/openclaw/version 2>/dev/null || true)"
if [[ -n "$expected_ref" && -n "$pinned_ref" ]]; then
  if [[ "$expected_ref" == "$pinned_ref" ]]; then
    echo "[OK] OPENCLAW_REF matches pinned ref ($expected_ref)"
  else
    echo "[WARN] OPENCLAW_REF mismatch expected=$expected_ref actual=$pinned_ref"
    [[ $state -lt 1 ]] && state=1
  fi
else
  echo "[WARN] unable to verify OPENCLAW_REF"
  [[ $state -lt 1 ]] && state=1
fi

if [[ -f /etc/systemd/system/openclaw.service ]]; then
  echo "[OK] openclaw.service file present"
else
  echo "[FAIL] openclaw.service missing"
  state=2
fi

enabled_state="$(systemctl is-enabled openclaw.service 2>/dev/null || true)"
active_state="$(systemctl is-active openclaw.service 2>/dev/null || true)"
echo "service enabled: ${enabled_state:-unknown}"
echo "service active: ${active_state:-unknown}"

if [[ "$enabled_state" != "enabled" ]]; then
  echo "[WARN] openclaw.service not enabled"
  [[ $state -lt 1 ]] && state=1
fi
if [[ "$active_state" != "active" ]]; then
  echo "[FAIL] openclaw.service is not active"
  state=2
fi

if [[ $state -ne 0 ]]; then
  echo "--- Last 80 openclaw logs ---"
  journalctl -u openclaw --no-pager -n 80 || true
fi

case "$state" in
  0) echo "HEALTHCHECK OK"; exit 0 ;;
  1) echo "HEALTHCHECK DEGRADED"; exit 1 ;;
  *) echo "HEALTHCHECK FAILED"; exit 2 ;;
esac
