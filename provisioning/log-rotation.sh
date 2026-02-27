#!/usr/bin/env bash
set -euo pipefail

cat >/etc/logrotate.d/openclaw <<'EOF'
/var/log/openclaw/*.log {
  daily
  rotate 7
  compress
  missingok
  notifempty
  copytruncate
}
EOF
