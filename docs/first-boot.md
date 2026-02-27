# First Boot Behavior

On first boot, `clawos-bootstrap.service` runs once and must:

- ensure SSH is enabled and reachable
- configure network policy for `eth0` (DHCP default)
- apply optional static IP only when explicitly enabled in template-derived env
- install/configure OpenClaw
- enable/start `openclaw-gateway.service`

After successful run, bootstrap marks completion and exits permanently.
