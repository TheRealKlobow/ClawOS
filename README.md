# ClawOS

Production-ready Raspberry Pi OS image for running OpenClaw Gateway headless on LAN.

## v1 scope

- LAN-only (Ethernet `eth0`)
- DHCP by default
- Optional static IP via `image/config/network.template.yaml` (off by default)
- No Wi-Fi auto-join
- No interactive prompts on boot
- Deterministic boot path: system boots -> bootstrap runs once -> gateway starts -> SSH reachable
- Zero secrets committed to git

## Quick start

1. Copy templates:
   - `cp .env.example .env`
   - Fill only local/private values in `.env`
2. Build image:
   - `bash image/build.sh`
3. Flash image to SD and boot Pi on Ethernet.

## Security model

- No tokens, API keys, or private IPs are committed.
- Runtime secrets are loaded from environment files generated outside git.
- Templates (`*.template`, `.env.example`) are safe to commit.

## Repo structure

See `docs/architecture.md` and `docs/build-flow.md`.
