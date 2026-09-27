#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

# Usage: omagate-display-action.sh on|off CONNECTOR
#
# Runtime only: monitors.conf is never touched, so `hyprctl reload`, logging
# out, or rebooting always brings a display back. "on" is exactly that
# reload, which restores your own monitor settings.
#
# Refuses to turn off a built-in panel, and refuses to turn off the last
# display that is still on, so you can never end up with a black screen.

action="${1:-}"
connector="${2:-}"

case "$action" in
  on|off) ;;
  *)
    echo "usage: omagate-display-action.sh on|off CONNECTOR" >&2
    exit 2
    ;;
esac

[[ "$connector" =~ ^[A-Za-z0-9-]{1,32}$ ]] || {
  echo "invalid connector name" >&2
  exit 2
}

case "$connector" in
  eDP-*|LVDS-*|DSI-*)
    echo "refusing to change the built-in display" >&2
    exit 3
    ;;
esac

command -v hyprctl >/dev/null 2>&1 || {
  echo "hyprctl is not available" >&2
  exit 4
}

if [ "$action" = "on" ]; then
  exec hyprctl reload
fi

# `hyprctl monitors` (without "all") lists only the displays that are on.
others="$(
  hyprctl monitors -j | CONNECTOR="$connector" python3 -c '
import json, os, sys
on = [m.get("name") for m in json.load(sys.stdin) if not m.get("disabled")]
me = os.environ["CONNECTOR"]
print(len([n for n in on if n != me]) if me in on else -1)
'
)"

[ "$others" != "-1" ] || {
  echo "$connector is not an active display" >&2
  exit 5
}

[ "$others" -ge 1 ] || {
  echo "refusing to turn off the only display that is on" >&2
  exit 6
}

exec hyprctl keyword monitor "$connector,disable"
