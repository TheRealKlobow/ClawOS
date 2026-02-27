#!/usr/bin/env bash
set -euo pipefail

if systemctl is-active --quiet openclaw-gateway.service; then
  exit 0
fi

systemctl restart openclaw-gateway.service
sleep 2
systemctl is-active --quiet openclaw-gateway.service
