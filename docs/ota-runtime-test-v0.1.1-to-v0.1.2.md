# OTA Runtime Update Test: v0.1.1 -> v0.1.2

Goal: validate runtime-only update on a live Pi without reflashing.

## Preconditions

- Device currently on `v0.1.1` (`cat /etc/clawos/version`)
- Network access to GitHub releases
- `AUTO_UPDATE=false` (manual update path)

## Commands

```bash
set -euo pipefail

cat /etc/clawos/version
cat /etc/clawos/clawos.env

sudo systemctl status openclaw-gateway --no-pager

sudo clawos-update

cat /etc/clawos/version
sudo systemctl status openclaw-gateway --no-pager
sudo journalctl -u openclaw-gateway --no-pager | tail -n 100
sudo tail -n 200 /var/log/clawos-update.log
```

## Pass criteria

- `/etc/clawos/version` changes from `v0.1.1` to `v0.1.2`
- gateway returns active after update
- update log shows checksum verified and apply completed
- no reflashing required
