#!/usr/bin/env bash
set -euo pipefail

# Minimal v1 hardening for deterministic headless operation
if [[ "${SSH_DISABLE_PASSWORD:-true}" == "true" ]]; then
  sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
  # Do not start/restart ssh during image build; let systemd manage first runtime start.
fi
