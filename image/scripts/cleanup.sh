#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATE_FILE="$ROOT_DIR/out/work/state/build-state.env"
[[ -f "$STATE_FILE" ]] || exit 0
# shellcheck disable=SC1090
source "$STATE_FILE"

# best-effort cleanup, never fail caller
set +e

if [[ -n "${MNT_ROOT:-}" ]]; then
  for p in run proc sys dev; do
    if findmnt -rn "$MNT_ROOT/$p" >/dev/null 2>&1; then
      umount "$MNT_ROOT/$p"
    fi
  done
  if findmnt -rn "$MNT_ROOT" >/dev/null 2>&1; then
    umount "$MNT_ROOT"
  fi
fi

if [[ "${KPARTX_USED:-0}" == "1" && -n "${LOOP_DEV:-}" ]]; then
  kpartx -dv "$LOOP_DEV" >/dev/null 2>&1
fi

if [[ -n "${LOOP_DEV:-}" ]] && losetup "$LOOP_DEV" >/dev/null 2>&1; then
  losetup -d "$LOOP_DEV" >/dev/null 2>&1
fi

exit 0
