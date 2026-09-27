#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

# Usage: omagate-network-action.sh connect|disconnect IFACE
#
# Goes through NetworkManager, so no saved connection or config file is
# changed: "connect" always undoes "disconnect". Only physical Wi-Fi and
# Ethernet interfaces are accepted; loopback and virtual ones are refused.

action="${1:-}"
iface="${2:-}"

case "$action" in
  connect|disconnect) ;;
  *)
    echo "usage: omagate-network-action.sh connect|disconnect IFACE" >&2
    exit 2
    ;;
esac

[[ "$iface" =~ ^[A-Za-z0-9_.-]{1,15}$ ]] || {
  echo "invalid interface name" >&2
  exit 2
}

[ -e "/sys/class/net/$iface/device" ] || {
  echo "$iface is not a physical network interface" >&2
  exit 3
}

command -v nmcli >/dev/null 2>&1 || {
  echo "NetworkManager (nmcli) is not available" >&2
  exit 4
}

exec nmcli device "$action" "$iface"
