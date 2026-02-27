# Build Flow

Linux builder only.

## Exact command

```bash
set -a; source .env; set +a; bash image/build.sh
```

## Pipeline

1. `prepare-base-image.sh`
   - Linux/tool/root preflight
   - safe workdir checks
   - copy base image -> `out/clawos-pi.img`
2. `inject-overlay.sh`
   - loop attach + kpartx map
   - deterministic root partition detection
3. `mount-overlay.sh`
   - mount rootfs rw
   - copy overlays with `cp -a`
4. `enable-services.sh`
   - offline systemd symlink enable + verification
5. `validate-image.sh`
   - artifact checks
6. `image/build.sh`
   - produces `out/clawos-pi.img.xz`

Cleanup runs via trap and always attempts unmount + detach.
