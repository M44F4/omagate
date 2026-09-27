#!/usr/bin/env bash
set -uo pipefail
export LC_ALL=C

if ! command -v boltctl >/dev/null 2>&1; then
    printf '%s\n' '{"available":false,"devices":[]}'
    exit 0
fi

python3 - <<'PY'
import json
import subprocess

try:
    result = subprocess.run(
        ["boltctl", "list"],
        text=True,
        capture_output=True,
        check=False
    )
except Exception:
    print('{"available":false,"devices":[]}')
    raise SystemExit

output = result.stdout or ""

blocks = []
current = []

for line in output.splitlines():
    if line.strip():
        current.append(line.rstrip())
    elif current:
        blocks.append(current)
        current = []

if current:
    blocks.append(current)

devices = []

for block in blocks:
    first = block[0].strip()

    if first.startswith("●"):
        first = first[1:].strip()

    if not first:
        continue

    data = {"name": first}

    for line in block[1:]:
        line = line.strip().lstrip("├─└│ ")

        if ":" not in line:
            continue

        key, value = line.split(":", 1)
        key = key.strip().lower().replace(" ", "_")
        value = value.strip()

        if value:
            data[key] = value

    status = data.get("status", data.get("authorized", ""))

    devices.append({
        "canAuthorize": bool(data.get("uuid"))
            and status.split()[0:1] in (["connected"], ["auth-error"]),
        "name": data.get("name", first),
        "vendor": data.get("vendor", ""),
        "type": data.get("type", ""),
        "uuid": data.get("uuid", ""),
        "status": data.get(
            "status",
            data.get("authorized", "")
        )
    })

# Without a Thunderbolt/USB4 controller (no domainN in sysfs) nothing can
# ever show up here, and the panel says so instead of a bare empty list.
import glob
controller = bool(glob.glob("/sys/bus/thunderbolt/devices/domain*"))

print(json.dumps({
    "available": True,
    "controller": controller,
    "devices": devices
}, separators=(",", ":")))
PY
