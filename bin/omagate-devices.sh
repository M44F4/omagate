#!/usr/bin/env bash
set -uo pipefail
export LC_ALL=C

# Walks up from a block device's /sys/class/block/<kname>/device symlink to
# find the USB device node (the sysfs dir with idVendor, not an interface
# dir, which has a colon in its name) that owns it.
sysfs_port_for_block() {
  local kname="$1" node="/sys/class/block/$1/device" path
  [ -e "$node" ] || return 1
  path=$(readlink -f "$node") || return 1
  while [ "$path" != "/" ]; do
    if [ -f "$path/idVendor" ] && [[ "$(basename "$path")" != *:* ]]; then
      basename "$path"
      return 0
    fi
    path=$(dirname "$path")
  done
  return 1
}

interface_classes_for_port() {
  local port="$1" iface classes=()
  for iface in "/sys/bus/usb/devices/$port":*; do
    [ -f "$iface/bInterfaceClass" ] || continue
    classes+=("$(cat "$iface/bInterfaceClass")")
  done
  (IFS=,; echo "${classes[*]}")
}

hid_present_for_port() {
  interface_classes_for_port "$1" | tr ',' '\n' | grep -qx "03"
}

# Display hint only (row icon), never used for any safety decision. Mice
# commonly expose an extra keyboard interface for macro keys, so the product
# name wins first, then a mouse interface outranks a keyboard one.
hid_kind_for_port() {
  local port="$1" name="${2,,}" iface proto has_kbd=false has_mouse=false
  case "$name" in
    *mouse*|*trackball*|*touchpad*|*trackpad*) echo mouse; return ;;
    *keyboard*|*keypad*) echo keyboard; return ;;
  esac
  for iface in "/sys/bus/usb/devices/$port":*; do
    [ "$(cat "$iface/bInterfaceClass" 2>/dev/null)" = "03" ] || continue
    proto=$(cat "$iface/bInterfaceProtocol" 2>/dev/null || echo "")
    [ "$proto" = "01" ] && has_kbd=true
    [ "$proto" = "02" ] && has_mouse=true
  done
  if $has_mouse; then echo mouse
  elif $has_kbd; then echo keyboard
  else echo ""
  fi
}

device_name_for_port() {
  local port="$1"
  local dir="/sys/bus/usb/devices/$1"
  local manufacturer product vendor_db model_db

  manufacturer=$(cat "$dir/manufacturer" 2>/dev/null || true)
  manufacturer="${manufacturer%"${manufacturer##*[![:space:]]}"}"

  product=$(cat "$dir/product" 2>/dev/null || true)
  product="${product%"${product##*[![:space:]]}"}"

  # Prefer the real USB product string when the device provides one.
  if [ -n "$product" ]; then
    if [ -n "$manufacturer" ]; then
      echo "$manufacturer $product"
    else
      echo "$product"
    fi
    return
  fi

  # Some devices expose no USB string descriptors. Fall back to udev's
  # hardware database for a human-readable vendor/model name.
  vendor_db=""
  model_db=""

  if command -v udevadm >/dev/null 2>&1; then
    while IFS='=' read -r key value; do
      case "$key" in
        ID_VENDOR_FROM_DATABASE)
          vendor_db="$value"
          ;;
        ID_MODEL_FROM_DATABASE)
          model_db="$value"
          ;;
      esac
    done < <(
      udevadm info         --query=property         --path="$dir"         2>/dev/null || true
    )
  fi

  if [ -n "$vendor_db" ] && [ -n "$model_db" ]; then
    echo "$vendor_db $model_db"
  elif [ -n "$vendor_db" ]; then
    echo "$vendor_db"
  elif [ -n "$model_db" ]; then
    echo "$model_db"
  else
    echo "USB device ($port)"
  fi
}

removable_for_port() {
  local val
  val=$(cat "/sys/bus/usb/devices/$1/removable" 2>/dev/null || echo "unknown")
  [ "$val" = "removable" ] && echo true || echo false
}

# Missing/unreadable reads as authorized: the attribute only exists once the
# usbcore driver has bound to the device, and the default is always 1.
authorized_for_port() {
  local val
  val=$(cat "/sys/bus/usb/devices/$1/authorized" 2>/dev/null || echo "1")
  [ "$val" = "1" ] && echo true || echo false
}

. "$(dirname "$(readlink -f "$0")")/omagate-ledger.sh"

# Blocked by OmaGate itself (in the ledger), as opposed to by USBGuard or
# another policy, which OmaGate must leave alone.
omagate_blocked_for_port() {
  local id
  id=$(omagate_identity "$1") && omagate_ledger_has "$id" && echo true || echo false
}

vendor_product_for_port() {
  local port="$1" dir="/sys/bus/usb/devices/$1" vendor product
  vendor=$(cat "$dir/idVendor" 2>/dev/null || echo "0000")
  product=$(cat "$dir/idProduct" 2>/dev/null || echo "0000")
  echo "${vendor}:${product}"
}

snapshot_file="$HOME/.local/state/omarchy/m44f4.omagate/trusted-snapshot.json"

trusted_for_port() {
  local port="$1" vp="$2"
  [ -f "$snapshot_file" ] || { echo false; return; }
  if jq -e --arg port "$port" --arg vp "$vp" \
      '.devices[]? | select(.sysfsPort == $port and .idVendorProduct == $vp)' \
      "$snapshot_file" >/dev/null 2>&1; then
    echo true
  else
    echo false
  fi
}

entries="[]"
claimed_ports=()

# --- USB mass-storage block devices ---
while IFS= read -r line; do
  [ -z "$line" ] && continue
  kname=$(jq -r '.kname' <<<"$line")
  devpath=$(jq -r '.path' <<<"$line")
  ro=$(jq -r '.ro' <<<"$line")
  mountpoint_json=$(jq -c '.mountpoint' <<<"$line")

  port=$(sysfs_port_for_block "$kname") || continue
  claimed_ports+=("$port")

  name=$(device_name_for_port "$port")
  removable=$(removable_for_port "$port")
  ifc=$(interface_classes_for_port "$port")
  if hid_present_for_port "$port"; then hid=true; else hid=false; fi
  vp=$(vendor_product_for_port "$port")
  trusted=$(trusted_for_port "$port" "$vp")
  authorized=$(authorized_for_port "$port")
  # Made read-only by OmaGate itself, as opposed to by something else,
  # which OmaGate must leave alone.
  omagate_ro=false
  if [ "$ro" = "true" ] && id=$(omagate_disk_identity "$kname") && omagate_ro_has "$id"; then
    omagate_ro=true
  fi

  entry=$(jq -n \
    --arg name "$name" \
    --arg devpath "$devpath" \
    --argjson omagateReadOnly "$omagate_ro" \
    --argjson mountpoint "$mountpoint_json" \
    --argjson removable "$removable" \
    --argjson readonly "$ro" \
    --arg sysfsPort "$port" \
    --arg interfaceClass "$ifc" \
    --argjson hidPresent "$hid" \
    --argjson trusted "$trusted" \
    --argjson authorized "$authorized" \
    '{kind: "storage", name: $name, devpath: $devpath, mountpoint: $mountpoint,
      removable: $removable, readonly: $readonly, omagateReadOnly: $omagateReadOnly, sysfsPort: $sysfsPort,
      interfaceClass: $interfaceClass, hidPresent: $hidPresent, trusted: $trusted,
      authorized: $authorized}')
  entries=$(jq --argjson e "$entry" '. + [$e]' <<<"$entries")
done < <(lsblk -J -o NAME,KNAME,PATH,TRAN,TYPE,RM,RO,MOUNTPOINT 2>/dev/null | jq -c '
  .blockdevices[]?
  | select(.tran == "usb" and .type == "disk" and .rm == true)
  | {kname, path, ro,
     mountpoint: (.mountpoint // ([(.children // [])[]?.mountpoint] | map(select(. != null)) | first // null))}
')

# --- other hot-pluggable USB devices (block feature candidates) ---
# Root hubs (basename "usbN") and interface nodes (basename has a colon)
# are skipped, as are hubs (bDeviceClass 09) -- blocking a hub would sever
# every device downstream of it, not just itself.
for dir in /sys/bus/usb/devices/*; do
  base=$(basename "$dir")
  [[ "$base" == *:* ]] && continue
  [[ "$base" == usb* ]] && continue
  [ -f "$dir/idVendor" ] || continue

  already_listed=false
  for p in "${claimed_ports[@]:-}"; do
    [ "$p" = "$base" ] && already_listed=true && break
  done
  $already_listed && continue

  devclass=$(cat "$dir/bDeviceClass" 2>/dev/null || echo "")
  [ "$devclass" = "09" ] && continue

  name=$(device_name_for_port "$base")
  removable=$(removable_for_port "$base")
  ifc=$(interface_classes_for_port "$base")
  if hid_present_for_port "$base"; then hid=true; else hid=false; fi
  hidkind=""
  $hid && hidkind=$(hid_kind_for_port "$base" "$name")
  vp=$(vendor_product_for_port "$base")
  trusted=$(trusted_for_port "$base" "$vp")
  authorized=$(authorized_for_port "$base")
  omagate_blocked=false
  [ "$authorized" = "false" ] && omagate_blocked=$(omagate_blocked_for_port "$base")

  entry=$(jq -n \
    --arg name "$name" \
    --argjson removable "$removable" \
    --arg sysfsPort "$base" \
    --arg interfaceClass "$ifc" \
    --argjson hidPresent "$hid" \
    --arg hidKind "$hidkind" \
    --argjson trusted "$trusted" \
    --argjson authorized "$authorized" \
    --argjson omagateBlocked "$omagate_blocked" \
    '{kind: "usb", name: $name, devpath: null, mountpoint: null,
      removable: $removable, readonly: null, sysfsPort: $sysfsPort,
      interfaceClass: $interfaceClass, hidPresent: $hidPresent, hidKind: $hidKind,
      trusted: $trusted, authorized: $authorized, omagateBlocked: $omagateBlocked}')
  entries=$(jq --argjson e "$entry" '. + [$e]' <<<"$entries")
done

echo "$entries"
