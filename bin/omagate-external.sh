#!/usr/bin/env bash
set -uo pipefail
export LC_ALL=C

python3 - <<'PY'
import glob
import json
import os
import subprocess

INTERNAL_PREFIXES = (
    "eDP-",
    "LVDS-",
    "DSI-",
)

# Hyprland knows the monitor's model name and the mode actually in use;
# sysfs only has the connector and the mode list. Fall back to sysfs when
# hyprctl is unavailable or the output is disabled.
monitors = {}
try:
    p = subprocess.run(["hyprctl", "monitors", "all", "-j"],
                       text=True, capture_output=True, check=False, timeout=2)
    for m in json.loads(p.stdout or "[]"):
        if m.get("name"):
            monitors[m["name"]] = m
except Exception:
    monitors = {}

active_count = sum(1 for m in monitors.values() if not m.get("disabled", False))

results = []

for status_path in sorted(glob.glob("/sys/class/drm/*/status")):
    connector = os.path.basename(os.path.dirname(status_path))

    if connector.startswith("card"):
        connector = connector.split("-", 1)[1] if "-" in connector else connector

    if any(connector.startswith(prefix) for prefix in INTERNAL_PREFIXES):
        continue

    try:
        with open(status_path, "r", encoding="utf-8") as f:
            status = f.read().strip().lower()
    except OSError:
        continue

    if status != "connected":
        continue

    base = os.path.dirname(status_path)

    enabled = ""
    enabled_path = os.path.join(base, "enabled")
    try:
        with open(enabled_path, "r", encoding="utf-8") as f:
            enabled = f.read().strip()
    except OSError:
        pass

    modes = []
    modes_path = os.path.join(base, "modes")
    try:
        with open(modes_path, "r", encoding="utf-8") as f:
            modes = [x.strip() for x in f if x.strip()]
    except OSError:
        pass

    mon = monitors.get(connector, {})
    model = " ".join(
        x for x in (mon.get("make", ""), mon.get("model", "")) if x
    ).strip()
    name = model or mon.get("description", "") or "External display"

    mode = modes[0] if modes else ""
    active = bool(mon) and not mon.get("disabled", False)
    if active and mon.get("width") and mon.get("height"):
        mode = "%dx%d" % (mon["width"], mon["height"])
        if mon.get("refreshRate"):
            mode += "@%dHz" % round(mon["refreshRate"])

    results.append({
        "kind": "display",
        "name": name,
        "connector": connector,
        "status": "Enabled" if active else "Connected",
        "enabled": enabled,
        "mode": mode,
        # Mirrors omagate-display-action.sh: never the last display that is on.
        "canTurnOff": active and active_count > 1,
        "canTurnOn": bool(mon) and not active,
    })

print(json.dumps(results, separators=(",", ":")))
PY
