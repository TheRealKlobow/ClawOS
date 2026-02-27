# ClawOS v0.1.1 Linux Build + Fresh Flash Proof Checklist

Use this checklist exactly for release evidence capture.

## A) Linux builder proof

- [ ] Record distro + kernel:
  - `uname -a`
  - `cat /etc/os-release`
- [ ] Record tool versions:
  - `losetup --version`
  - `kpartx -V`
  - `mount --version`
  - `lsblk --version`
- [ ] Run clean build command:
  - `set -a; source .env; set +a; bash image/build.sh`
- [ ] Capture `out/` artifact tree with sizes:
  - `find out -maxdepth 3 -type f -printf "%p %s bytes\n" | sort`
- [ ] Generate release files:
  - `bash scripts/release-image.sh`
- [ ] Capture SHA256:
  - `sha256sum out/clawos-pi.img.xz`
  - `cat out/SHA256SUMS.txt`

## B) Fresh hardware flash proof

- [ ] Flash `out/clawos-pi.img.xz` to SD/USB
- [ ] Record hardware model:
  - `tr -d '\0' </proc/device-tree/model`
- [ ] Record base image source used for build (URL + filename)

## C) First boot + runtime proof

- [ ] SSH reachable on LAN
- [ ] Port evidence:
  - `ss -tulpn | grep ':22\|:18789'`
- [ ] Bootstrap ran once:
  - `ls -l /var/lib/clawos/bootstrap.done`
  - `systemctl status clawos-bootstrap --no-pager`
- [ ] Gateway status evidence:
  - `systemctl status openclaw-gateway --no-pager`
  - `journalctl -u openclaw-gateway --no-pager | tail -n 200`

## D) Update safety proof

- [ ] Confirm installed version:
  - `cat /etc/clawos/version`
- [ ] Confirm update config defaults:
  - `cat /etc/clawos/clawos.env` (AUTO_UPDATE=false)
- [ ] Run pre-release validator:
  - `bash scripts/pre-release-validate.sh`
- [ ] Capture `/var/log/clawos-update.log` after manual update test
- [ ] Verify checksum failure path aborts safely (no apply executed)

## E) Release decision gate

- [ ] Boot → update → restart cycle proven on fresh hardware
- [ ] Evidence archived in release notes / CI artifacts
- [ ] Only then mark v0.1.1 as official release
