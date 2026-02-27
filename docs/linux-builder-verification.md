# Linux Builder Verification (Evidence Capture)

Run on Linux builder host.

## 1) Host + tool versions

```bash
set -euo pipefail
uname -a
cat /etc/os-release
losetup --version
kpartx -V
mount --version
lsblk --version
```

## 2) Build command

```bash
set -euo pipefail
set -a; source .env; set +a
bash image/build.sh
```

## 3) Output tree with file sizes

```bash
set -euo pipefail
find out -maxdepth 3 -type f -printf "%p %s bytes\n" | sort
```

## 4) SHA256 artifact

```bash
set -euo pipefail
sha256sum out/clawos-pi.img.xz
bash scripts/release-image.sh
cat out/SHA256SUMS.txt
```

## 5) Boot validation (on Pi)

```bash
# device identity
auto=$(tr -d '\0' </proc/device-tree/model); echo "$auto"

# services
systemctl status clawos-bootstrap --no-pager
systemctl status openclaw-gateway --no-pager
journalctl -u openclaw-gateway --no-pager | tail -n 200

# network reachability + port
ss -tulpn | grep ':22\|:18789'

# first-boot completion marker
ls -l /var/lib/clawos/bootstrap.done
```
