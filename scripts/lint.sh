#!/usr/bin/env bash
set -euo pipefail

# template sanity checks
[[ -f image/config/network.template.yaml ]]
[[ -f image/config/openclaw.env.template ]]
[[ -f systemd/openclaw-gateway.service ]]

echo "Lint OK"
