#!/usr/bin/env bash
set -euo pipefail

systemctl is-enabled openclaw-gateway.service >/dev/null
systemctl is-active openclaw-gateway.service >/dev/null
command -v openclaw >/dev/null
