# ClawOS v0.1.1

KLB ClawOS - Built by KLB Groups.com

## Summary

v0.1.1 focuses on branding consistency, safe update controls, and release-hardening verification paths for Raspberry Pi headless LAN deployments.

## What’s included

- Permanent KLB branding in OS-layer overlays:
  - `/etc/issue`
  - `/etc/motd` (runtime-generated during bootstrap)
  - `/etc/hostname` default `clawos`
  - `/etc/clawos/version` set to `v0.1.1`
- Safe updater path:
  - `/usr/local/bin/clawos-update`
  - SHA256 verification required before apply
  - abort on checksum mismatch
  - logs at `/var/log/clawos-update.log`
- Optional automatic update:
  - `clawos-update.timer` daily at 03:00
  - gated by `/etc/clawos/clawos.env` (`AUTO_UPDATE=true` required)
- Bootstrap installer URL fix:
  - `https://openclaw.ai/install.sh`
  - retries + timeout + bootstrap log file

## Scope + security posture

- LAN-only v1 (Ethernet-first)
- No Wi-Fi auto-join in v1
- No secrets shipped in image artifacts
- No secrets committed in git
- SSH expected open on `22/tcp`
- Gateway port `18789/tcp` only when user config exposes beyond loopback

## Artifacts

- `clawos-pi.img.xz`
- `SHA256SUMS.txt`

## Verify checksums

```bash
sha256sum -c SHA256SUMS.txt
```

## Validation requirement before official v0.1.1 release mark

Release is considered official only after clean hardware validation completes:

1. Fresh flash
2. Boot
3. SSH reachable
4. Gateway starts
5. Update path validated (including checksum-failure abort)
6. Gateway restart confirmed after successful apply

## Upgrade note

Fresh flash is recommended for v0.1.x validation runs.

## Disclaimer

Provided as-is, without warranty. Operators are responsible for network exposure, credentials, update policies, and safe deployment practices.
