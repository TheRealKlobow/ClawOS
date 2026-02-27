# Security

- Secrets are never committed.
- Runtime token/env files live on device (`/etc/default`), created from local input.
- SSH password login should be disabled by default.
- Gateway should remain loopback-bound unless explicitly changed.
- Any remote exposure must be layered behind secure transport.
