#!/usr/bin/env bash
set -euo pipefail

mkdir -p /var/lib/clawos /etc/default

# Install OpenClaw if missing (idempotent)
if ! command -v openclaw >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/openclaw/openclaw/main/install.sh | bash
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
