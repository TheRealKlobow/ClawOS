# Architecture

ClawOS v1 is a deterministic headless image flow:

1. **Base image**: Raspberry Pi OS Lite.
2. **Overlay injection**: systemd units + bootstrap scripts + templates.
3. **First boot** (`clawos-bootstrap.service`):
   - prepares runtime files from templates
   - applies LAN networking policy (DHCP default; optional static)
   - installs/configures OpenClaw Gateway
   - enables and starts `openclaw-gateway.service`
4. **Steady state**:
   - gateway managed by systemd (`Restart=always`)
   - periodic health checks + logs

## Design constraints

- Headless only.
- No interactive prompts at boot.
- No secrets in git.
- Stability > feature breadth.
- LAN-first operation (eth0).
