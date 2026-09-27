#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C

# Usage: omagate-kill-devport.sh PID [CHILD_PID...]
#
# The first PID is the service itself and must pass every check. Any extra
# PIDs are listening child processes folded into the same row (JupyterLab's
# kernels, for example); one that already exited or fails a check is skipped
# instead of aborting the stop.

[ $# -ge 1 ] || {
  echo "usage: omagate-kill-devport.sh PID [CHILD_PID...]" >&2
  exit 2
}

current_user="$(id -un)"

check_pid() {
  local pid="$1" user="" process=""

  [[ "$pid" =~ ^[0-9]+$ ]] || {
    echo "invalid PID: $pid" >&2
    return 2
  }

  [ "$pid" -gt 1 ] || {
    echo "refusing to terminate protected PID $pid" >&2
    return 3
  }

  read -r user process < <(
    ps -o user= -o comm= -p "$pid" 2>/dev/null
  ) || true

  [ -n "$process" ] || {
    echo "process $pid not found" >&2
    return 4
  }

  [ -n "$user" ] || {
    echo "unable to determine owner of $pid" >&2
    return 5
  }

  [ "$user" = "$current_user" ] || {
    echo "refusing process $pid owned by another user" >&2
    return 6
  }

  [ "$user" != "root" ] || {
    echo "refusing root process $pid" >&2
    return 7
  }

  case "${process,,}" in
    node|nodejs|npm|pnpm|jupyter|jupyter-lab|jupyter-notebook|yarn|bun|python|python3|uvicorn|gunicorn|\
    java|gradle|gradlew|cargo|rustc|go|docker-proxy|postgres|\
    postgresql|redis-server|vite|next|next-server|deno)
      ;;
    *)
      echo "process $pid is not an approved development process" >&2
      return 8
      ;;
  esac
}

main="$1"
shift

check_pid "$main" || exit $?

targets=("$main")
for pid in "$@"; do
  if check_pid "$pid"; then
    targets+=("$pid")
  fi
done

kill -TERM "${targets[@]}"
