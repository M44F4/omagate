#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

disk="${1:?usage: omagate-eject.sh <device>}"

[ -b "$disk" ] || { echo "omagate-eject: not a block device: $disk" >&2; exit 1; }

# Only what the panel offers: a USB disk, never an internal one.
[ "$(lsblk -dno TRAN "$disk" 2>/dev/null)" = "usb" ] \
  || { echo "omagate-eject: not a USB disk: $disk" >&2; exit 1; }

status=0

mounted_parts=$(lsblk -nr -o PATH,MOUNTPOINT "$disk" 2>/dev/null | awk '$2 != "" {print $1}') || true
if [ -n "$mounted_parts" ]; then
  while IFS= read -r part; do
    udisksctl unmount -b "$part" || status=1
  done <<<"$mounted_parts"
fi

if ! udisksctl power-off -b "$disk"; then
  status=1
  eject "$disk" || status=1
fi

exit "$status"
