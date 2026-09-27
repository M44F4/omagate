#!/usr/bin/env bash
set -uo pipefail
export LC_ALL=C

python3 - <<'PY'
import json
import os
import subprocess

def get_json(args):
    try:
        p = subprocess.run(args, text=True, capture_output=True, check=False)
        if p.returncode != 0:
            return []
        return json.loads(p.stdout or "[]")
    except Exception:
        return []

links = get_json(["ip", "-j", "-brief", "link"])
addresses = get_json(["ip", "-j", "-brief", "address"])

# NetworkManager's view of each device ("connected", "disconnected",
# "unmanaged", ...). Connect/Disconnect is only offered for devices it manages.
nm_state = {}
try:
    p = subprocess.run(["nmcli", "-t", "-f", "DEVICE,STATE", "device"],
                       text=True, capture_output=True, check=False, timeout=2)
    for line in (p.stdout or "").splitlines():
        device, _, state = line.rpartition(":")
        if device:
            nm_state[device] = state
except Exception:
    nm_state = {}

addr_map = {
    x.get("ifname"): x
    for x in addresses
    if x.get("ifname")
}

out = []

for item in links:
    name = item.get("ifname")

    if not name:
        continue

    if name == "lo":
        kind = "Loopback"
    elif os.path.isdir(f"/sys/class/net/{name}/wireless"):
        kind = "Wi-Fi"
    elif os.path.exists(f"/sys/class/net/{name}/device"):
        kind = "Ethernet"
    else:
        kind = "Interface"

    addr_item = addr_map.get(name, {})
    addr_list = []

    # Loopback addresses are not useful in the compact UI.
    if name != "lo":
        for addr in addr_item.get("addr_info", []):
            local = addr.get("local")
            if local:
                addr_list.append(local)

    nm = nm_state.get(name, "")
    physical = kind in ("Wi-Fi", "Ethernet")

    out.append({
        "name": name,
        "canDisconnect": physical and nm.startswith("connected"),
        "canConnect": physical and nm == "disconnected",
        "type": kind,
        "state": item.get("operstate", "UNKNOWN"),
        "mac": item.get("address", ""),
        "addresses": addr_list
    })

print(json.dumps(out, separators=(",", ":")))
PY
