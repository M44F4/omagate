# Sourced by omagate-block.sh, omagate-unblock-all.sh, omagate-writeprotect.sh,
# and omagate-devices.sh.
#
# Two ledgers record what OmaGate itself changed, so that undoing it only
# touches those changes and never ones made by USBGuard, a udev rule, or any
# other policy:
#
#   blocked   USB device connections OmaGate deauthorized
#   readonly  disks OmaGate made read-only
#
# OmaGate refuses to block a device that is already deauthorized, or to make
# read-only a disk that already is, so it never records someone else's change
# as its own. A ledger cannot tell, though, if another policy later makes the
# same change to something OmaGate had already changed: an entry means
# OmaGate made that change, not that OmaGate is the only thing that did.
#
# Both live in /run, so they are root-owned and cleared on reboot, just like
# the kernel state they describe. Each line identifies one attachment:
#
#   blocked:   <sysfs port> <vendor:product> <busnum> <devnum>
#   readonly:  <disk name> <diskseq> [<partitions OmaGate remounted, comma-separated>]
#
# The kernel assigns a new devnum (USB) and a new diskseq (disks) every time
# something is plugged in, so a device that is unplugged and plugged back in
# never matches an old line.

OMAGATE_LEDGER_DIR="/run/omagate"
OMAGATE_LEDGER="$OMAGATE_LEDGER_DIR/blocked"
OMAGATE_RO_LEDGER="$OMAGATE_LEDGER_DIR/readonly"

omagate_identity() {
  local dir="/sys/bus/usb/devices/$1" vendor product bus dev
  vendor=$(cat "$dir/idVendor" 2>/dev/null) || return 1
  product=$(cat "$dir/idProduct" 2>/dev/null) || return 1
  bus=$(cat "$dir/busnum" 2>/dev/null) || return 1
  dev=$(cat "$dir/devnum" 2>/dev/null) || return 1
  echo "$1 $vendor:$product $bus $dev"
}

omagate_disk_identity() {
  local seq
  seq=$(cat "/sys/block/$1/diskseq" 2>/dev/null) || return 1
  [[ "$seq" =~ ^[0-9]+$ ]] || return 1
  echo "$1 $seq"
}

# --- generic helpers: <ledger file> <line or key> ---

omagate_ledger_file_has() {
  [ -f "$1" ] && grep -qxF -- "$2" "$1"
}

# Replaces a ledger with stdin, atomically. Root only.
omagate_ledger_file_write() {
  local tmp
  [ ! -L "$OMAGATE_LEDGER_DIR" ] || return 1
  mkdir -p "$OMAGATE_LEDGER_DIR" && chmod 755 "$OMAGATE_LEDGER_DIR" || return 1
  tmp=$(mktemp "$OMAGATE_LEDGER_DIR/.ledger.XXXXXX") || return 1
  cat > "$tmp" && chmod 644 "$tmp" && mv -f "$tmp" "$1"
}

# Every line except the one whose first field is exactly $2 (a plain string
# compare: a port like 1-1.2 must not be read as a regex).
omagate_ledger_file_without() {
  [ -f "$1" ] || return 0
  awk -v key="$2" '$1 != key' "$1"
}

omagate_ledger_file_add() {
  local key="${2%% *}"
  { omagate_ledger_file_without "$1" "$key"; echo "$2"; } | omagate_ledger_file_write "$1"
}

omagate_ledger_file_remove() {
  omagate_ledger_file_without "$1" "$2" | omagate_ledger_file_write "$1"
}

# --- blocked ledger (keyed by sysfs port) ---

omagate_ledger_has() { omagate_ledger_file_has "$OMAGATE_LEDGER" "$1"; }
omagate_ledger_write() { omagate_ledger_file_write "$OMAGATE_LEDGER"; }
omagate_ledger_add() { omagate_ledger_file_add "$OMAGATE_LEDGER" "$1"; }
omagate_ledger_remove_port() { omagate_ledger_file_remove "$OMAGATE_LEDGER" "$1"; }

# --- readonly ledger (keyed by disk name) ---

# $1 is a disk identity ("sda 5"); matches whatever remount list follows it.
omagate_ro_has() {
  [ -f "$OMAGATE_RO_LEDGER" ] && grep -qE -- "^$1( |\$)" "$OMAGATE_RO_LEDGER"
}

# Prints the partitions OmaGate remounted read-only for this disk identity.
omagate_ro_remounted() {
  [ -f "$OMAGATE_RO_LEDGER" ] || return 0
  grep -E -- "^$1( |\$)" "$OMAGATE_RO_LEDGER" | head -1 | cut -s -d' ' -f3 | tr ',' '\n'
}
omagate_ro_add() { omagate_ledger_file_add "$OMAGATE_RO_LEDGER" "$1"; }
omagate_ro_remove() { omagate_ledger_file_remove "$OMAGATE_RO_LEDGER" "$1"; }
