#!/usr/bin/env bash
set -uo pipefail
export LC_ALL=C

# --all lists every listening process you own, not only known dev servers.
# Stopping stays limited to known dev servers either way (see killable).
scope="dev"
[ "${1:-}" = "--all" ] && scope="all"

OMAGATE_SCOPE="$scope" python3 - <<'PY'
import json
import os
import pwd
import re
import subprocess

DEV_PROCESSES = {
    "node",
    "nodejs",
    "npm",
    "pnpm",
    "jupyter",
    "jupyter-lab",
    "jupyter-notebook",
    "yarn",
    "bun",
    "python",
    "python3",
    "uvicorn",
    "gunicorn",
    "java",
    "gradle",
    "gradlew",
    "cargo",
    "rustc",
    "go",
    "docker-proxy",
    "postgres",
    "postgresql",
    "redis-server",
    "vite",
    "next",
    "next-server",
    "deno",
}

# Friendly names, keyed by what the process runs. "kind" picks the row icon.
PROCESS_NAMES = {
    "jupyter-lab": ("JupyterLab", "jupyter"),
    "jupyter-notebook": ("Jupyter Notebook", "jupyter"),
    "jupyter-server": ("Jupyter Server", "jupyter"),
    "jupyter": ("Jupyter", "jupyter"),
    "uvicorn": ("Uvicorn", "python"),
    "gunicorn": ("Gunicorn", "python"),
    "flask": ("Flask", "python"),
    "streamlit": ("Streamlit", "python"),
    "mkdocs": ("MkDocs", "python"),
    "fastapi": ("FastAPI", "python"),
    "vite": ("Vite", "node"),
    "next": ("Next.js", "node"),
    "next-server": ("Next.js", "node"),
    "nuxt": ("Nuxt", "node"),
    "nuxi": ("Nuxt", "node"),
    "astro": ("Astro", "node"),
    "webpack": ("webpack", "node"),
    "webpack-dev-server": ("webpack", "node"),
    "react-scripts": ("Create React App", "node"),
    "remix": ("Remix", "node"),
    "svelte-kit": ("SvelteKit", "node"),
    "@sveltejs/kit": ("SvelteKit", "node"),
    "ng": ("Angular", "node"),
    "@angular/cli": ("Angular", "node"),
    "parcel": ("Parcel", "node"),
    "nodemon": ("nodemon", "node"),
    "storybook": ("Storybook", "node"),
    "expo": ("Expo", "node"),
    "http-server": ("http-server", "node"),
    "serve": ("serve", "node"),
    "json-server": ("json-server", "node"),
    "docker-proxy": ("Docker", "docker"),
    "postgres": ("PostgreSQL", "database"),
    "postgresql": ("PostgreSQL", "database"),
    "redis-server": ("Redis", "database"),
    "deno": ("Deno", "node"),
    "bun": ("Bun", "node"),
    "java": ("Java", "java"),
    "gradle": ("Gradle", "java"),
    "gradlew": ("Gradle", "java"),
    "cargo": ("Cargo", "rust"),
    "rustc": ("Rust", "rust"),
    "go": ("Go", "go"),
}

PYTHON_MODULES = {
    "ipykernel_launcher": ("Jupyter kernel", "jupyter"),
    "ipykernel": ("Jupyter kernel", "jupyter"),
    "jupyterlab": ("JupyterLab", "jupyter"),
    "notebook": ("Jupyter Notebook", "jupyter"),
    "jupyter_server": ("Jupyter Server", "jupyter"),
    "http.server": ("Python http.server", "python"),
    "uvicorn": ("Uvicorn", "python"),
    "gunicorn": ("Gunicorn", "python"),
    "flask": ("Flask", "python"),
    "streamlit": ("Streamlit", "python"),
    "mkdocs": ("MkDocs", "python"),
    "fastapi": ("FastAPI", "python"),
}

SHOW_ALL = os.environ.get("OMAGATE_SCOPE") == "all"

CURRENT_USER = os.environ.get("USER", "")
if not CURRENT_USER:
    try:
        CURRENT_USER = subprocess.check_output(
            ["id", "-un"],
            text=True,
            stderr=subprocess.DEVNULL
        ).strip()
    except Exception:
        CURRENT_USER = ""

def run(args):
    try:
        return subprocess.run(
            args,
            text=True,
            capture_output=True,
            check=False
        )
    except Exception:
        return None

def read_proc(pid, name):
    try:
        with open(f"/proc/{pid}/{name}", "rb") as f:
            return f.read()
    except OSError:
        return b""

def parent_pid(pid):
    # The command name can contain spaces and parentheses; the fields that
    # follow the last ")" are fixed: state, then ppid.
    stat = read_proc(pid, "stat").decode(errors="replace")
    fields = stat.rsplit(")", 1)[-1].split()
    try:
        return int(fields[1])
    except (IndexError, ValueError):
        return 0

def process_user(pid):
    try:
        return pwd.getpwuid(os.stat(f"/proc/{pid}").st_uid).pw_name
    except (OSError, KeyError):
        return ""

def process_cwd(pid):
    try:
        return os.readlink(f"/proc/{pid}/cwd")
    except OSError:
        return ""

def process_argv(pid):
    raw = read_proc(pid, "cmdline")
    return [a.decode(errors="replace") for a in raw.split(b"\0") if a]

def script_argument(argv):
    """What an interpreter runs: ("module", name) for -m, else ("script", path)."""
    i = 1
    while i < len(argv):
        arg = argv[i]
        if arg == "-m" and i + 1 < len(argv):
            return ("module", argv[i + 1])
        if arg == "-c":
            return ("", "")
        if arg in ("-X", "-W", "--require", "-r", "--import", "--loader"):
            i += 2
            continue
        if arg.startswith("-"):
            i += 1
            continue
        return ("script", arg)
    return ("", "")

def node_package(path):
    """The npm package a node_modules path belongs to, if any."""
    match = re.search(r"node_modules/(?:\.bin/)?(@[^/]+/[^/]+|[^/]+)", path)
    return match.group(1) if match else ""

def describe(process, argv):
    """A friendly (name, kind) for a listening process."""
    lowered = process.lower()
    kind, target = script_argument(argv)
    base = os.path.basename(target)
    stem = os.path.splitext(base)[0]

    if lowered.startswith("python") or lowered in ("uvicorn", "gunicorn"):
        if kind == "module":
            for module, found in PYTHON_MODULES.items():
                if target == module or target.startswith(module + "."):
                    return found
            return (target, "python")
        if stem in PROCESS_NAMES:
            return PROCESS_NAMES[stem]
        if base == "manage.py" and "runserver" in argv:
            return ("Django", "python")
        if base:
            return (base, "python")
        return PROCESS_NAMES.get(lowered, ("Python", "python"))

    if lowered in ("node", "nodejs"):
        for candidate in (node_package(target), stem):
            if candidate in PROCESS_NAMES:
                return PROCESS_NAMES[candidate]
        if base:
            return (base, "node")
        return ("Node.js", "node")

    if lowered in PROCESS_NAMES:
        return PROCESS_NAMES[lowered]

    return (process, "other")

WILDCARDS = {"*", "0.0.0.0", "[::]", "::"}

def is_loopback(address):
    address = address.split("%", 1)[0].strip("[]")
    return address.startswith("127.") or address in ("::1", "localhost")

def exposure(addresses):
    """"local" when only loopback, "network" when on every interface, else the address."""
    bare = [a.split("%", 1)[0] for a in addresses]
    if any(a in WILDCARDS for a in bare):
        return "network"
    remote = [a.strip("[]") for a in bare if not is_loopback(a)]
    return remote[0] if remote else "local"

ss = run(["ss", "-lntupH"])

if ss is None:
    print("[]")
    raise SystemExit

# pid -> {"process": name, "sockets": {(protocol, address, port)}}
listeners = {}

for line in (ss.stdout or "").splitlines():
    columns = line.split()

    if len(columns) < 5:
        continue

    protocol = columns[0].lower()

    if protocol not in {"tcp", "udp"}:
        continue

    match = re.match(r"^(.*):(\d+)$", columns[4])
    if not match:
        continue

    address = match.group(1)
    port = int(match.group(2))

    match = re.search(r'users:\(\("([^"]+)",pid=(\d+)', line)
    if not match:
        continue

    process = match.group(1)
    pid = int(match.group(2))

    entry = listeners.setdefault(pid, {"process": process, "sockets": set()})
    entry["sockets"].add((protocol, address, port))

def is_dev(pid):
    return listeners[pid]["process"].lower() in DEV_PROCESSES

visible = {pid for pid in listeners if SHOW_ALL or is_dev(pid)}
users = {pid: process_user(pid) for pid in visible}

# A process listening under another listening process of the same user is
# folded into it: JupyterLab's kernels each open several ZeroMQ ports, and
# they belong on the JupyterLab row rather than on a dozen rows of their own.
# A dev process only folds under another dev process, so it stays stoppable.
def service_root(pid):
    root = pid
    current = parent_pid(pid)
    seen = {pid}

    while current > 1 and current not in seen:
        seen.add(current)
        if (current in visible
                and users[current] == users[pid]
                and (is_dev(current) or not is_dev(pid))):
            root = current
        current = parent_pid(current)

    return root

groups = {}
for pid in visible:
    groups.setdefault(service_root(pid), []).append(pid)

def port_order(socket):
    protocol, _address, port = socket
    return (protocol != "tcp", port)

def killable(pid):
    # Only a known development process of the current user, never PID 1 or
    # root (matches omagate-kill-devport.sh).
    user = users[pid]
    return bool(
        is_dev(pid)
        and CURRENT_USER
        and user == CURRENT_USER
        and pid != 1
        and user != "root"
    )

def folder(cwd):
    return cwd if cwd and cwd != "/" else ""

results = []

for root, members in groups.items():
    process = listeners[root]["process"]
    argv = process_argv(root)
    name, kind = describe(process, argv)
    sockets = sorted(listeners[root]["sockets"], key=port_order)
    ports = sorted({port for _protocol, _address, port in sockets})
    cwd = process_cwd(root)
    user = users[root]

    children = []
    for pid in sorted(members):
        if pid == root:
            continue
        child_name, child_kind = describe(listeners[pid]["process"], process_argv(pid))
        children.append({
            "pid": pid,
            "name": child_name,
            "kind": child_kind,
            "ports": sorted({port for _p, _a, port in listeners[pid]["sockets"]}),
            "project": folder(process_cwd(pid)),
        })

    # Stopping a row stops its folded children too; only the ones the kill
    # script would accept are passed along.
    results.append({
        "pid": root,
        "pids": [root] + [c["pid"] for c in children if killable(c["pid"])],
        "name": name,
        "kind": kind,
        "process": process,
        "port": sockets[0][2],
        "protocol": sockets[0][0],
        "ports": ports,
        "exposure": exposure([address for _p, address, _port in sockets]),
        "user": user,
        "userOwned": bool(CURRENT_USER and user == CURRENT_USER),
        "command": " ".join(argv) or process,
        "cwd": cwd,
        "project": folder(cwd),
        "children": children,
        "docker": process.lower() == "docker-proxy",
        "dev": is_dev(root),
        "killable": killable(root),
    })

results.sort(key=lambda x: (x["port"], x["name"].lower(), x["pid"]))

print(json.dumps(results, separators=(",", ":")))
PY
