#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

# Enumerates every currently-connected hot-pluggable, non-hub USB device
# (same filter as omagate-devices.sh's "other USB devices" pass: skip
# interface nodes, root hubs, and hubs themselves) and records
# {sysfsPort, idVendorProduct} for each. Anything in this snapshot is
# permanently exempt from the block feature (guard #1 in omagate-block.sh) --
# this is what guarantees an already-attached keyboard/trackpad/webcam/dock
# can never be blocked, regardless of how the kernel classifies it.
# Re-running it (Settings > Re-trust) replaces the snapshot with whatever is
# connected right now.

state_dir="$HOME/.local/state/omarchy/m44f4.omagate"
snapshot_file="$state_dir/trusted-snapshot.json"

mkdir -p "$state_dir"

devices="[]"
for dir in /sys/bus/usb/devices/*; do
  base=$(basename "$dir")
  [[ "$base" == *:* ]] && continue
  [[ "$base" == usb* ]] && continue
  [ -f "$dir/idVendor" ] || continue

  devclass=$(cat "$dir/bDeviceClass" 2>/dev/null || echo "")
  [ "$devclass" = "09" ] && continue

  # A device OmaGate currently holds deauthorized must never become trusted
  # by a re-snapshot: it would lose its block control while staying blocked.
  [ "$(cat "$dir/authorized" 2>/dev/null || echo 1)" = "0" ] && continue

  vendor=$(cat "$dir/idVendor" 2>/dev/null || echo "0000")
  product=$(cat "$dir/idProduct" 2>/dev/null || echo "0000")

  entry=$(jq -n --arg port "$base" --arg vp "${vendor}:${product}" \
    '{sysfsPort: $port, idVendorProduct: $vp}')
  devices=$(jq --argjson e "$entry" '. + [$e]' <<<"$devices")
done

jq -n --arg createdAt "$(date -u +%Y-%m-%dT%H:%M:%SZ)" --argjson devices "$devices" \
  '{createdAt: $createdAt, devices: $devices}' > "$snapshot_file"

echo "$snapshot_file"
