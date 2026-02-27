# Operations

## Check status

- `systemctl status clawos-bootstrap`
- `systemctl status openclaw-gateway`
- `journalctl -u openclaw-gateway -f`

## Health script

- `/usr/local/bin/openclaw-healthcheck.sh`

## Recovery

- Re-run bootstrap only if needed:
  - `sudo rm -f /var/lib/clawos/bootstrap.done`
  - `sudo systemctl restart clawos-bootstrap`
