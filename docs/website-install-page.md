# ClawOS Install Page (Website Copy)

## Hero

**ClawOS**

A practical, open-source deployment layer for running OpenClaw on Raspberry Pi with deterministic setup, clear failure modes, and production-minded operational defaults.

- Stable: `v0.1.20-stable`
- Open source: https://github.com/TheRealKlobow/ClawOS

---

## What it solves

Most self-hosted AI deployments fail in operations, not ideas:

- config drift between runtime contexts
- startup failures with unclear causes
- fragile update paths
- hard-to-reproduce installs

ClawOS standardizes that layer so setup is repeatable and diagnosable.

---

## Quick Install

1. Download latest stable ClawOS image from GitHub Releases.
2. Flash SD with Raspberry Pi Imager or balenaEtcher.
3. Boot Pi and SSH in:

```bash
ssh claw@<PI_IP>
clawos setup
```

Expected completion line:

```text
SETUP_RESULT: PASS (mode=... port=... token=...)
```

Optional runtime update (if image is older than latest stable runtime):

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
```

---

## Security architecture (intentional)

ClawOS defaults are security-first. Manual approval and explicit toggles are intentional architecture decisions, not friction bugs.

- token auth by default
- strict origin controls for Control UI
- insecure LAN HTTP convenience is opt-in only

For private dev LAN testing (less secure), explicit flags can be enabled by operator action.

---

## Project context

ClawOS was built in an intense 24-hour engineering sprint as a proof of AI-assisted systems delivery.

Important framing:

- this is not hype-first AI marketing
- this is disciplined human-led engineering with AI acceleration
- outcomes were validated through real setup failures, iterative fixes, and release gating

It demonstrates a practical pattern:

**human intent + AI execution + operational validation**.

---

## Manual approval philosophy

Manual approval exists to keep humans accountable at high-impact boundaries (credentials, exposure, risky operations). This is deliberate safety architecture for long-term reliability.

---

## Updates

ClawOS uses checksum-verified runtime artifacts.

- download release runtime + checksum
- verify
- apply
- restart service
- verify health

---

## Hardware support status

- ✅ Raspberry Pi 4: tested and validated
- ⏳ Other Raspberry Pi models: planned for future testing

If you test on other models, share reproducible logs so support can be expanded.

---

## Contribute

ClawOS is open source and community-driven.

Contributions are welcome: reliability, security, docs, CI hardening.

When reporting issues, include:

- device model
- exact version
- exact commands run
- `systemctl` + `journalctl` snippets

Community contact:

- Discord: `@Klobow`

A dedicated Discord server is planned. If you want to help with development or support, reach out.

---

## Credits

ClawOS is a real human + AI collaboration:

- OpenClaw ecosystem and runtime foundation
- ChatGPT-assisted debugging and documentation iteration
- Human product direction, release decisions, and validation ownership

This is AI-assisted engineering with accountability, not autopilot.
