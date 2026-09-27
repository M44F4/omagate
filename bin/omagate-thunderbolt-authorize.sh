#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

# Usage: omagate-thunderbolt-authorize.sh UUID
#
# Authorizes a connected Thunderbolt device for this session only (nothing
# is stored; unplugging it undoes this). OmaGate deliberately offers no
# deauthorize or forget: a dock can carry your keyboard, mouse, sound, and
# monitor, and cutting it off from here could leave you without them.

uuid="${1:-}"

[[ "$uuid" =~ ^[0-9A-Fa-f-]{36}$ ]] || {
  echo "invalid device UUID" >&2
  exit 2
}

command -v boltctl >/dev/null 2>&1 || {
  echo "boltctl is not installed" >&2
  exit 3
}

exec boltctl authorize "$uuid"
