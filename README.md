# ClawOS

**ClawOS • Made by KLB Groups**

ClawOS is a Raspberry Pi-focused, open-source runtime image and update stack for running OpenClaw reliably on LAN/home infrastructure.

- Repository: https://github.com/TheRealKlobow/ClawOS
- Stable release: `v0.1.20-stable`
- License: MIT (see `LICENSE`)

## Quick Start (flash SD + run)

1. Download the latest **stable ClawOS image** from Releases.
2. Flash it to SD card (Raspberry Pi Imager or balenaEtcher).
3. Boot Pi on LAN and SSH in:

```bash
ssh claw@<PI_IP>
```

4. Run guided setup:

```bash
clawos setup
```

Expected completion line:

```text
SETUP_RESULT: PASS (mode=... port=... token=...)
```

5. Verify service is running:

```bash
sudo systemctl is-active openclaw-gateway.service
```

> Optional: if you flashed an older image, apply the latest stable runtime update from Releases (see Installation Guide below).
>
> Full architecture, security rationale, and operations guidance continue below and remain the authoritative documentation.

---

## What ClawOS is

ClawOS is a practical distribution layer around OpenClaw for Raspberry Pi:

- preconfigured runtime conventions
- guided gateway setup (`clawos setup`)
- service lifecycle management
- repeatable runtime updates
- operational helpers (`clawos status`, `clawos doctor`, `clawos update`)

It is designed for people who want a working local AI operator node without manually stitching together every service and config file.

---

## What problem it solves

Raw infrastructure setup is where many projects fail:

- drift between config files and service runtime
- token/auth mismatch between user and root contexts
- unclear startup failures
- hard-to-repeat updates

ClawOS focuses on solving that operational layer so setup is deterministic and recoverable.

---

## Why this project exists (and why it matters)

ClawOS is a proof of concept in **AI-assisted system engineering**:

- built in roughly **24 hours** of focused iteration
- created by someone who had **never previously built a full operating system distribution flow**
- developed through structured prompt-driven collaboration with OpenClaw + ChatGPT

This is not “AI did everything.”
This is **human direction + AI execution + human validation**.

That model is the point.

---

## Open source commitment

ClawOS is fully open source in this repository.

Principles:

- transparent implementation
- auditable scripts and service units
- reproducible release artifacts
- no secret logic hidden outside the repo

---

## Philosophy and vision

### Philosophy

1. **Secure by default**
   - loopback-first where possible
   - explicit opt-in for insecure LAN HTTP convenience modes

2. **Deterministic operations**
   - known setup flow
   - clear fail reasons
   - minimal ambiguity

3. **Operational honesty**
   - explicit diagnostics over “magic”
   - no fake success messages

4. **Human-in-control AI**
   - agent power is useful only when deployment controls are explicit

### Vision

A reliable, self-hosted, AI-native operations substrate where normal people can deploy advanced automation safely, repeatedly, and fast.

---

## Installation guide (step-by-step)

> This is the production path for a fresh Raspberry Pi.

### 0) Requirements

- Raspberry Pi (Ethernet recommended)
- SD card flashed with ClawOS image from Releases
- SSH access to the Pi

### 1) Flash the SD card

- Download latest stable image from GitHub Releases
- Flash using Raspberry Pi Imager or balenaEtcher
- Boot the Pi and wait for network DHCP lease

### 2) SSH into the Pi

```bash
ssh claw@<PI_IP>
```

### 3) (Optional) apply latest stable runtime update

Use this only if your flashed image is older than current stable runtime:

```bash
set -euo pipefail
TMP="$(mktemp -d)"
cd "$TMP"

curl -fL --retry 3 -o clawos-runtime-v0.1.20-stable.tar.gz \
  https://github.com/TheRealKlobow/ClawOS/releases/download/v0.1.20-stable/clawos-runtime-v0.1.20-stable.tar.gz

curl -fL --retry 3 -o SHA256SUMS-v0.1.20-stable.txt \
  https://github.com/TheRealKlobow/ClawOS/releases/download/v0.1.20-stable/SHA256SUMS-v0.1.20-stable.txt

sha256sum -c SHA256SUMS-v0.1.20-stable.txt
tar -xzf clawos-runtime-v0.1.20-stable.tar.gz
sudo bash ./apply.sh

echo "v0.1.20-stable" | sudo tee /etc/clawos/version >/dev/null
cat /etc/clawos/version
```

### 4) Run guided setup

```bash
clawos setup
```

Expected completion line:

```text
SETUP_RESULT: PASS (mode=... port=... token=...)
```

### 5) Verify service state

```bash
sudo systemctl is-active openclaw-gateway.service
sudo systemctl status openclaw-gateway.service --no-pager | sed -n '1,25p'
```

Expected: `active` and `Active: active (running)`

---

## Manual approval: what it is and why it exists

ClawOS is designed for environments where automation may trigger high-impact actions.
Manual approval exists so humans remain accountable at critical boundaries.

Typical examples:

- network exposure changes
- sensitive credential changes
- destructive maintenance tasks

This is intentional friction for safety, not a UX accident.

---

## Dashboard / UI connection notes

If dashboard is reachable but shows device-identity/auth restrictions over plain HTTP LAN, this is expected secure-default behavior.

For local development convenience (less secure), you can explicitly enable insecure UI auth:

```bash
sudo openclaw config set gateway.controlUi.allowInsecureAuth true
sudo openclaw config set gateway.controlUi.dangerouslyDisableDeviceAuth true
sudo openclaw config set gateway.controlUi.dangerouslyAllowHostHeaderOriginFallback true
sudo openclaw config set gateway.controlUi.allowedOrigins '["http://<PI_IP>:<PORT>","http://127.0.0.1:<PORT>","http://localhost:<PORT>"]'
sudo systemctl restart openclaw-gateway.service
```

Use in dashboard:

- WebSocket URL: `ws://<PI_IP>:<PORT>`
- Gateway token: your configured token

---

## How updates work

ClawOS updates are runtime-asset driven.

- release artifact: `clawos-runtime-<version>.tar.gz`
- checksum file: `SHA256SUMS-<version>.txt`
- updates are applied via `apply.sh`
- service is restarted after runtime files are installed

Recommended update flow:

1. download release + checksum
2. verify checksum
3. apply runtime
4. verify service health

---

## Security model

### Defaults

- gateway token auth required
- controlled origin checks for Control UI
- explicit LAN insecure mode opt-in

### Recommended hardening

- use long random tokens (not short test tokens)
- keep insecure UI flags off outside private dev LAN
- prefer HTTPS / secure context where possible
- restrict network access via firewall/router
- rotate tokens periodically

---

## Operations reference

### Core commands

```bash
clawos setup
clawos status
clawos doctor
sudo clawos update
openclaw gateway status
```

### Service control

```bash
sudo systemctl restart openclaw-gateway.service
sudo systemctl status openclaw-gateway.service --no-pager
sudo journalctl -u openclaw-gateway.service -n 80 --no-pager
```

---

## Contributing

Contributions are welcome.

Best contribution types:

- reproducible bug reports (commands + logs + expected vs actual)
- setup reliability improvements
- security hardening improvements
- documentation clarity improvements
- CI/release process hardening

When opening issues/PRs, include:

- Pi model + OS base
- exact ClawOS version
- exact commands run
- relevant `systemctl` and `journalctl` output

---

## Credits

ClawOS is the result of real **human + AI collaboration**.

- **Human direction, product decisions, validation, and release accountability**
- **OpenClaw runtime and ecosystem**
- **ChatGPT-assisted systems engineering, debugging iteration, and documentation refinement**

This project demonstrates a practical pattern:
**humans lead, AI accelerates, reliability comes from disciplined validation.**

---

## Disclaimer

ClawOS is provided **as-is**, without warranty.
You are responsible for deployment, network exposure, credentials, and operational safety.
