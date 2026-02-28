#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/out"
VERSION="$(tr -d '\r\n' < "$ROOT_DIR/image/overlays/etc/clawos/version")"
RUNTIME_NAME="clawos-runtime-${VERSION}.tar.gz"
STAGE_DIR="$OUT_DIR/runtime-stage"
PAYLOAD_DIR="$STAGE_DIR/payload"

rm -rf "$STAGE_DIR"
mkdir -p "$PAYLOAD_DIR/etc/systemd/system" "$PAYLOAD_DIR/usr/local/bin" "$PAYLOAD_DIR/etc/clawos" "$PAYLOAD_DIR/etc/default" "$PAYLOAD_DIR/opt/clawos" "$PAYLOAD_DIR/opt/openclaw"

# ClawOS-managed runtime files only
cp -a "$ROOT_DIR/image/overlays/usr/local/bin/clawos-bootstrap.sh" "$PAYLOAD_DIR/usr/local/bin/"
cp -a "$ROOT_DIR/image/overlays/usr/local/bin/clawos-healthcheck.sh" "$PAYLOAD_DIR/usr/local/bin/" 2>/dev/null || true
cp -a "$ROOT_DIR/image/overlays/usr/local/bin/openclaw-healthcheck.sh" "$PAYLOAD_DIR/usr/local/bin/"
cp -a "$ROOT_DIR/image/overlays/usr/local/bin/clawos-update" "$PAYLOAD_DIR/usr/local/bin/"

cp -a "$ROOT_DIR/image/overlays/etc/systemd/system/openclaw-gateway.service" "$PAYLOAD_DIR/etc/systemd/system/"
cp -a "$ROOT_DIR/image/overlays/etc/systemd/system/openclaw.service" "$PAYLOAD_DIR/etc/systemd/system/"
for f in "$ROOT_DIR"/image/overlays/etc/systemd/system/clawos-*.service "$ROOT_DIR"/image/overlays/etc/systemd/system/clawos-*.timer; do
  [[ -f "$f" ]] && cp -a "$f" "$PAYLOAD_DIR/etc/systemd/system/"
done

cp -a "$ROOT_DIR/image/overlays/etc/clawos/." "$PAYLOAD_DIR/etc/clawos/"
[[ -f "$ROOT_DIR/image/overlays/etc/default/clawos-path" ]] && cp -a "$ROOT_DIR/image/overlays/etc/default/clawos-path" "$PAYLOAD_DIR/etc/default/"

if [[ -d "$ROOT_DIR/image/overlays/opt/clawos" ]]; then
  cp -a "$ROOT_DIR/image/overlays/opt/clawos/." "$PAYLOAD_DIR/opt/clawos/"
fi
if [[ -d "$ROOT_DIR/image/overlays/opt/openclaw" ]]; then
  cp -a "$ROOT_DIR/image/overlays/opt/openclaw/." "$PAYLOAD_DIR/opt/openclaw/"
fi

cat >"$STAGE_DIR/apply.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="/var/log/clawos-update.log"
exec >>"$LOG_FILE" 2>&1

echo "[$(date -Is)] runtime apply start"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PAYLOAD_DIR="$SCRIPT_DIR/payload"
[[ -d "$PAYLOAD_DIR" ]] || { echo "missing payload directory"; exit 1; }

systemctl stop openclaw.service || true
systemctl stop openclaw-gateway.service || true

cp -a "$PAYLOAD_DIR/." /

chmod 0755 /usr/local/bin/clawos-bootstrap.sh || true
chmod 0755 /usr/local/bin/openclaw-healthcheck.sh || true
chmod 0755 /usr/local/bin/clawos-update || true

systemctl daemon-reload
if systemctl list-unit-files | grep -q '^openclaw.service'; then
  systemctl enable openclaw.service || true
  systemctl start openclaw.service
else
  systemctl start openclaw-gateway.service
fi

echo "[$(date -Is)] runtime apply complete"
EOF
chmod 0755 "$STAGE_DIR/apply.sh"

mkdir -p "$OUT_DIR"
(
  cd "$STAGE_DIR"
  tar -czf "$OUT_DIR/$RUNTIME_NAME" apply.sh payload
)

echo "$OUT_DIR/$RUNTIME_NAME"
