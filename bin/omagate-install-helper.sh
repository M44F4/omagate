#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

# Usage: sudo bash omagate-install-helper.sh [install|uninstall]
#
# Installs OmaGate's privileged helpers (block, unblock-all, write-protect,
# and the ledger they share) into a root-owned directory. The panel only
# ever runs these root-owned copies through pkexec, never the scripts in the
# plugin folder, which the desktop user can write to.
#
# Run it yourself from a terminal, once after installing OmaGate and again
# after each update (the panel says when). Uninstall reauthorizes anything
# OmaGate still has blocked, then removes the helpers.

dest="/usr/local/libexec/omagate"
helpers=(omagate-block.sh omagate-unblock-all.sh omagate-writeprotect.sh omagate-ledger.sh)

[ "$(id -u)" = "0" ] || {
  echo "Run this with sudo: sudo bash $0 ${1:-install}" >&2
  exit 1
}

src="$(dirname "$(readlink -f "$0")")"

case "${1:-install}" in
  install)
    version=$(jq -r '.version // empty' "$src/../manifest.json")
    [[ "$version" =~ ^[0-9A-Za-z.+-]{1,64}$ ]] || {
      echo "cannot read the plugin version from manifest.json" >&2
      exit 1
    }

    install -d -o root -g root -m 755 "$dest"
    for helper in "${helpers[@]}"; do
      install -o root -g root -m 755 "$src/$helper" "$dest/$helper"
    done
    printf '%s\n' "$version" > "$dest/VERSION"
    chown root:root "$dest/VERSION"
    chmod 644 "$dest/VERSION"

    echo "OmaGate helpers $version installed in $dest"
    ;;

  uninstall)
    if [ -x "$dest/omagate-unblock-all.sh" ]; then
      "$dest/omagate-unblock-all.sh" || echo "some devices could not be reauthorized" >&2
    fi
    rm -rf -- "$dest"
    echo "OmaGate helpers removed from $dest"
    ;;

  *)
    echo "usage: sudo bash $0 [install|uninstall]" >&2
    exit 2
    ;;
esac
