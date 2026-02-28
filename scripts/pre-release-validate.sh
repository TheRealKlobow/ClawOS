#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPDATER="$ROOT_DIR/image/overlays/usr/local/bin/clawos-update"
VERSION_FILE="$ROOT_DIR/image/overlays/etc/clawos/version"
ISSUE_FILE="$ROOT_DIR/image/overlays/etc/issue"
ENV_FILE="$ROOT_DIR/image/overlays/etc/clawos/clawos.env"
ENV_EXAMPLE="$ROOT_DIR/.env.example"
OPENCLAW_SERVICE="$ROOT_DIR/image/overlays/etc/systemd/system/openclaw.service"

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

pass() {
  echo "[OK] $*"
}

[[ -f "$UPDATER" ]] || fail "missing updater script"
[[ -f "$VERSION_FILE" ]] || fail "missing version file"
[[ -f "$ISSUE_FILE" ]] || fail "missing /etc/issue overlay"
[[ -f "$ENV_FILE" ]] || fail "missing clawos.env overlay"
[[ -f "$ENV_EXAMPLE" ]] || fail "missing .env.example"
[[ -f "$OPENCLAW_SERVICE" ]] || fail "missing openclaw.service overlay"

EXPECTED_VERSION="v0.1.8"
ACTUAL_VERSION="$(tr -d '\r\n' < "$VERSION_FILE")"
[[ "$ACTUAL_VERSION" == "$EXPECTED_VERSION" ]] || fail "version mismatch: expected $EXPECTED_VERSION got $ACTUAL_VERSION"
pass "version match ($EXPECTED_VERSION)"

grep -q "Version: $EXPECTED_VERSION" "$ISSUE_FILE" || fail "/etc/issue does not contain expected version"
pass "branding issue file contains expected version"

grep -q '^AUTO_UPDATE=false$' "$ENV_FILE" || fail "AUTO_UPDATE default must be false"
pass "AUTO_UPDATE default is false"

grep -q '^OPENCLAW_REF=' "$ENV_EXAMPLE" || fail "OPENCLAW_REF must be pinned in .env.example"
grep -q '^OPENCLAW_REF=[^[:space:]]\+$' "$ENV_EXAMPLE" || fail "OPENCLAW_REF must be non-empty in .env.example"
pass "OPENCLAW_REF pin present in .env.example"

grep -q '^ExecStart=/usr/local/bin/openclaw gateway$' "$OPENCLAW_SERVICE" || fail "openclaw.service ExecStart mismatch"
grep -q '^NoNewPrivileges=true$' "$OPENCLAW_SERVICE" || fail "openclaw.service hardening missing NoNewPrivileges"
pass "openclaw.service start command + hardening validated"

# Update dry-run (static behavior check): verify script includes current==latest no-op path
grep -q 'already on latest version' "$UPDATER" || fail "updater missing latest-version no-op guard"
pass "updater includes version-match no-op path"

# Checksum failure case (static behavior check): verify checksum check and fail-fast conditions exist
grep -q 'sha256sum -c' "$UPDATER" || fail "updater missing checksum verification"
grep -q 'checksum entry not found' "$UPDATER" || fail "updater missing checksum entry failure path"
pass "updater contains checksum failure handling"

echo "Pre-release validation checks passed"
