#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

device="${1:?usage: omagate-writeprotect.sh <device> <ro|rw>}"
mode="${2:?usage: omagate-writeprotect.sh <device> <ro|rw>}"

. "$(dirname "$(readlink -f "$0")")/omagate-ledger.sh"

refuse() {
  echo "omagate-writeprotect: $1" >&2
  exit 1
}

# Only what the panel offers: a whole, removable USB disk (the same rule as
# omagate-devices.sh). Never an internal disk, a partition, or a symlink
# that points somewhere else.
[[ "$device" =~ ^/dev/[a-z]+$ ]] || refuse "not a whole-disk device path: $device"
[ -b "$device" ] && [ ! -L "$device" ] || refuse "not a block device: $device"

read -r tran type rm < <(lsblk -dno TRAN,TYPE,RM "$device" 2>/dev/null) || true
[ "${tran:-}" = "usb" ] || refuse "not a USB device: $device"
[ "${type:-}" = "disk" ] || refuse "not a whole disk: $device"
[ "${rm:-}" = "1" ] || refuse "not removable storage: $device"

case "$mode" in
  ro|rw) ;;
  *) refuse "mode must be ro or rw, got: $mode" ;;
esac

# Like blocking, only undo what OmaGate did (see omagate-ledger.sh): a disk
# made read-only by a udev rule, a write blocker, or another policy is never
# made writable from here.
#
# The kernel only enforces a block device's read-only flag when a filesystem
# is mounted: writes to one already mounted read-write still go through. So
# "read-only" also remounts the disk's mounted filesystems read-only, and
# "writable" remounts only the ones OmaGate remounted.
disk="${device#/dev/}"
identity=$(omagate_disk_identity "$disk") || refuse "cannot identify disk: $device"
current=$(blockdev --getro "$device") || refuse "cannot read the read-only state of $device"

partitions=()
while read -r name kind; do
  [ "$kind" = "part" ] && partitions+=("$name")
done < <(lsblk -lnpo NAME,TYPE "$device")

# Mount points of one device, NUL-separated, with "rw" or "ro" before each.
mounts_of() {
  findmnt -J -S "$1" -o TARGET,OPTIONS 2>/dev/null \
    | jq -j '.filesystems[]? | (.options | split(",")[0]), "\u0000", .target, "\u0000"'
}

set_all() {  # --setro | --setrw on the disk and every partition
  local dev
  for dev in "$device" "${partitions[@]}"; do
    blockdev "$1" "$dev" || return 1
  done
}

if [ "$mode" = "ro" ]; then
  [ "$current" = "0" ] \
    || refuse "$device is already read-only (set by something else); leaving it alone"
  # Same for a single partition, or "writable" would later clear its flag.
  for part in "${partitions[@]}"; do
    [ "$(blockdev --getro "$part")" = "0" ] \
      || refuse "$part is already read-only (set by something else); leaving it alone"
  done

  remounted=()       # partitions
  remounted_at=()    # their mount points, to roll back
  rollback() {
    local mp
    for mp in "${remounted_at[@]}"; do mount -o remount,rw -- "$mp" || true; done
  }

  for part in "${partitions[@]}"; do
    changed=false
    while IFS= read -r -d '' opt && IFS= read -r -d '' target; do
      [ "$opt" = "rw" ] || continue
      if ! mount -o remount,ro -- "$target"; then
        rollback
        refuse "cannot remount $target read-only (a file may be open for writing); nothing was changed"
      fi
      remounted_at+=("$target")
      changed=true
    done < <(mounts_of "$part")
    $changed && remounted+=("${part#/dev/}")
  done

  list=$(IFS=,; echo "${remounted[*]}")
  # Recorded before locking the disk, so OmaGate can always undo its own.
  omagate_ro_add "$identity${list:+ $list}" || { rollback; refuse "cannot record the change"; }
  if ! set_all --setro; then
    set_all --setrw || true
    rollback
    omagate_ro_remove "$disk"
    refuse "failed to make $device read-only"
  fi
else
  omagate_ro_has "$identity" \
    || refuse "$device was not made read-only by OmaGate; leaving it alone"

  set_all --setrw || refuse "failed to make $device writable"

  status=0
  while IFS= read -r part; do
    [ -n "$part" ] || continue
    while IFS= read -r -d '' opt && IFS= read -r -d '' target; do
      [ "$opt" = "ro" ] || continue
      mount -o remount,rw -- "$target" || {
        echo "omagate-writeprotect: cannot remount $target writable" >&2
        status=1
      }
    done < <(mounts_of "/dev/$part")
  done < <(omagate_ro_remounted "$identity")

  omagate_ro_remove "$disk"
  exit "$status"
fi
