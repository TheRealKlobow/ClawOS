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
   - expand raw image size (default `+4G`) before partition/filesystem resize
2. `inject-overlay.sh`
   - loop attach + kpartx map
   - deterministic root partition detection
3. `expand-rootfs.sh`
   - resize partition 2 to 100% of image
   - run `e2fsck` + `resize2fs` before any chroot package installs
4. `mount-overlay.sh`
   - mount rootfs rw
   - copy overlays with `cp -a`
5. `provision-runtime.sh`
   - install runtime dependencies in chroot
   - install Node.js runtime (>=22.12.0)
   - enable Corepack + activate pnpm
6. `install-openclaw.sh`
   - requires pinned `OPENCLAW_REF`
   - clone OpenClaw into `/opt/openclaw` and checkout pinned ref
   - install/build with pnpm
   - verify `dist/entry.mjs` or `dist/entry.js`
7. `enable-services.sh`
   - offline systemd symlink enable + verification (`openclaw.service`, bootstrap, timers)
8. `validate-rootfs-runtime.sh`
   - chroot checks for node/npm and OpenClaw runtime presence
   - validates `openclaw.service` command/working directory/user
9. `validate-image.sh`
   - artifact checks

Cleanup runs via trap and always attempts unmount + detach.
