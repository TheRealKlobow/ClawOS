#!/usr/bin/env bash
set -euo pipefail

LOG_FILE="/var/log/clawos-bootstrap.log"
exec >>"$LOG_FILE" 2>&1

echo "[$(date -Is)] clawos-bootstrap start"

mkdir -p /var/lib/clawos /etc/default /etc/clawos

# Branding + version
hostnamectl set-hostname clawos || true
echo "clawos" >/etc/hostname
echo "v1.7.2" >/etc/clawos/version

cat >/etc/issue <<'EOF'
KLB ClawOS - Built by KLB Groups.com
Version: v1.7.2
EOF

PRIMARY_IP="$(hostname -I | awk '{print $1}')"
cat >/etc/motd <<EOF
KLB ClawOS - Built by KLB Groups.com
Device: $(hostname)
IP: ${PRIMARY_IP}
Gateway: ws://${PRIMARY_IP}:18789
Repo: https://github.com/TheRealKlobow/ClawOS
EOF

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

# Ensure SSH is active for headless management
systemctl enable ssh || true
systemctl restart ssh || true

# Enable and start gateway
systemctl daemon-reload
systemctl enable openclaw-gateway.service
systemctl restart openclaw-gateway.service

touch /var/lib/clawos/bootstrap.done
echo "[$(date -Is)] clawos-bootstrap complete"
