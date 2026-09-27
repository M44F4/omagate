#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

# Backs the Port Guard OFF fail-safe: reauthorizes the device connections
# OmaGate blocked (the ledger), and only those. A device that only USBGuard
# or another policy denied is not in the ledger, so it stays blocked. See
# omagate-ledger.sh for what the ledger can and cannot tell apart.

. "$(dirname "$(readlink -f "$0")")/omagate-ledger.sh"

[ -f "$OMAGATE_LEDGER" ] || exit 0

status=0
keep=()

while read -r port vp bus dev; do
  [ -n "${port:-}" ] || continue
  recorded="$port $vp $bus $dev"

  # Unplugged, or plugged in again since (new devnum): no longer ours.
  current=$(omagate_identity "$port") || continue
  [ "$current" = "$recorded" ] || continue

  auth_file="/sys/bus/usb/devices/$port/authorized"
  [ "$(cat "$auth_file" 2>/dev/null || echo 1)" = "0" ] || continue

  if ! echo 1 > "$auth_file" 2>/dev/null; then
    echo "omagate-unblock-all: failed to reauthorize $port" >&2
    keep+=("$recorded")
    status=1
  fi
done < "$OMAGATE_LEDGER"

if [ "${#keep[@]}" -gt 0 ]; then
  printf '%s\n' "${keep[@]}" | omagate_ledger_write
else
  : | omagate_ledger_write
fi

exit "$status"
