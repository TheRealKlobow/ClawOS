#!/usr/bin/env bash
set -euo pipefail

if command -v openclaw >/dev/null 2>&1; then
  echo "OpenClaw already installed"
  exit 0
fi

curl -fsSL https://raw.githubusercontent.com/openclaw/openclaw/main/install.sh | bash
