# ClawOS v0.1.1 Release Notes (Template)

## Highlights

- Deterministic Linux-only image builder
- Offline rootfs overlay injection
- Offline systemd enable for bootstrap + gateway
- Headless LAN-first defaults (DHCP on eth0)

## Artifacts

- `clawos-pi.img.xz`
- `SHA256SUMS.txt`

## Verification

```bash
sha256sum -c SHA256SUMS.txt
```

## Upgrade/Notes

- Fresh flash recommended for v0.1.0
- No secrets are shipped in artifacts

## Security and scope notes

- LAN-only in v1 (Ethernet-first)
- No Wi-Fi auto-join in v1
- No secrets are shipped in artifacts

## Known limitations

- Linux builder required for image build pipeline
- Wi-Fi auto-join intentionally excluded in v1
