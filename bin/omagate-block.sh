#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

# Writes 0/1 to a USB device's sysfs `authorized` attribute (deauthorize/
# reauthorize). Unauthorizing (0) re-verifies all three safety guards
# itself, independent of whatever the calling QML believes is true, so a
# stale UI state can never bypass them, and records the block in the ledger.
# Reauthorizing (1) is only allowed for a connection OmaGate itself blocked
# (it must be in the ledger), so a block made only by USBGuard or another
# policy is left alone.

. "$(dirname "$(readlink -f "$0")")/omagate-ledger.sh"

refuse() {
  echo "omagate-block: $1" >&2
  exit 1
}

port="${1:?usage: omagate-block.sh <sysfs-port> <0|1>}"
action="${2:?usage: omagate-block.sh <sysfs-port> <0|1>}"

[[ "$port" =~ ^[0-9]+(-[0-9]+)+(\.[0-9]+)*$ ]] || {
  echo "omagate-block: invalid sysfs port: $port" >&2
  exit 1
}

dev_dir="/sys/bus/usb/devices/$port"
[ -d "$dev_dir" ] || { echo "omagate-block: no such USB device: $port" >&2; exit 1; }

auth_file="$dev_dir/authorized"
[ -f "$auth_file" ] || {
  echo "omagate-block: device has no authorized attribute: $port" >&2
  exit 1
}

identity=$(omagate_identity "$port") || refuse "cannot identify device: $port"

case "$action" in
  1)
    omagate_ledger_has "$identity" \
      || refuse "$port was not blocked by OmaGate; leaving it to whatever blocked it"
    echo 1 > "$auth_file"
    omagate_ledger_remove_port "$port"
    exit 0
    ;;
  0)
    : # blocking -- guards below must all pass first
    ;;
  *)
    echo "omagate-block: action must be 0 or 1, got: $action" >&2
    exit 1
    ;;
esac

# --- guard 1: snapshot exemption ---
# A device present at snapshot time is permanently exempt, matched on
# port *and* vendor:product so a device later swapped into a previously
# trusted port doesn't silently inherit that trust.
#
# This runs as root under pkexec, so $HOME is root's home, not the desktop
# user's. The snapshot is read from the home of the user who invoked pkexec
# (PKEXEC_UID). Every failure here refuses the block (fail closed): no
# invoking user, no snapshot, or a snapshot that cannot be parsed.
[[ "${PKEXEC_UID:-}" =~ ^[0-9]+$ ]] || refuse "must be run through pkexec by the desktop user"
[ "$PKEXEC_UID" -ne 0 ] || refuse "refusing to block on behalf of root"

user_home=$(getent passwd "$PKEXEC_UID" | cut -d: -f6)
[ -n "$user_home" ] && [ -d "$user_home" ] || refuse "cannot find the home directory of uid $PKEXEC_UID"

snapshot_file="$user_home/.local/state/omarchy/m44f4.omagate/trusted-snapshot.json"

# A regular file owned by that user, not a symlink to somewhere else.
[ -f "$snapshot_file" ] && [ ! -L "$snapshot_file" ] \
  || refuse "no trusted-device snapshot; turn Port Guard on first"
[ "$(stat -c %u "$snapshot_file")" = "$PKEXEC_UID" ] \
  || refuse "trusted-device snapshot is not owned by uid $PKEXEC_UID"

vendor=$(cat "$dev_dir/idVendor" 2>/dev/null || echo "0000")
product=$(cat "$dev_dir/idProduct" 2>/dev/null || echo "0000")
vp="${vendor}:${product}"

matches=$(jq -r --arg port "$port" --arg vp "$vp" \
  '[.devices[] | select(.sysfsPort == $port and .idVendorProduct == $vp)] | length' \
  "$snapshot_file" 2>/dev/null) || refuse "cannot read the trusted-device snapshot"
[[ "$matches" =~ ^[0-9]+$ ]] || refuse "cannot read the trusted-device snapshot"
[ "$matches" -eq 0 ] || refuse "refusing to block trusted device: $port ($vp)"

# --- guard 2: removable-only ---
removable=$(cat "$dev_dir/removable" 2>/dev/null || echo "unknown")
if [ "$removable" != "removable" ]; then
  echo "omagate-block: refusing to block non-removable device: $port" >&2
  exit 1
fi

# --- guard 3: non-HID interface class ---
for iface in "$dev_dir":*; do
  [ -f "$iface/bInterfaceClass" ] || continue
  if [ "$(cat "$iface/bInterfaceClass")" = "03" ]; then
    echo "omagate-block: refusing to block device exposing a HID interface: $port" >&2
    exit 1
  fi
done

# Only a device that is currently authorized can be blocked. If something
# else (USBGuard, another policy) has already deauthorized it, OmaGate must
# not record that block as its own, or Port Guard off would later undo it.
# Checked last, right before the ledger entry, to keep the window small.
[ "$(cat "$auth_file" 2>/dev/null || echo 0)" = "1" ] \
  || refuse "$port is already deauthorized by something else; leaving it alone"

# Recorded before blocking, so a device can never end up blocked by OmaGate
# without an entry that lets OmaGate unblock it again.
omagate_ledger_add "$identity" || refuse "cannot record the block"
if ! echo 0 > "$auth_file"; then
  omagate_ledger_remove_port "$port"
  refuse "failed to block $port"
fi
