#!/usr/bin/env bash
# ~/.codespaces/startup.sh
# Safe, idempotent startup script run for interactive shells in Codespaces.
# - Starts docker compose services if found
# - Attempts to start a frontend dev server (npm run dev) non-blocking if a package.json with dev script is found
# - Respects env var overrides:
#     CODESPACES_FRONTEND_DIR  -> path to frontend dir (absolute or relative to workspace root)
#     CODESPACES_SKIP_FRONTEND -> if set (any value) will skip starting frontend
# Logs: ~/.codespaces/dev-server.log and /tmp/codespaces-docker-start.log

set -euo pipefail

# Only run for interactive shells
case "$-" in
  *i*) ;;
  *) return ;;
esac

# Prevent re-run in same shell
if [ -n "${CODESPACES_STARTUP_HAS_RUN:-}" ]; then
  return
fi
export CODESPACES_STARTUP_HAS_RUN=1

# Determine workspace root (prefer /workspace, then /workspaces/* heuristics)
find_workspace_root() {
  if [ -d "/workspace" ]; then
    echo "/workspace"
    return 0
  fi
  if [ -d "/workspaces" ]; then
    for d in /workspaces/*; do
      [ -d "$d" ] || continue
      # heuristic: repo folders tend to contain .git or package.json or index.html
      if [ -e "$d/.git" ] || [ -e "$d/package.json" ] || [ -e "$d/index.html" ]; then
        echo "$d"
        return 0
      fi
    done
  fi
  # fallback to current directory
  echo "$PWD"
  return 0
}

WORKSPACE_ROOT="$(find_workspace_root)"

# Helper: run docker compose up -d if a compose file exists
start_docker_compose_if_present() {
  local dcdir=""
  if [ -f "$WORKSPACE_ROOT/.devcontainer/docker-compose.yml" ]; then
    dcdir="$WORKSPACE_ROOT/.devcontainer"
  elif [ -f "$WORKSPACE_ROOT/docker-compose.yml" ]; then
    dcdir="$WORKSPACE_ROOT"
  fi

  if [ -n "$dcdir" ] && command -v docker >/dev/null 2>&1; then
    echo "Codespaces startup: starting docker compose services from $dcdir (logs -> /tmp/codespaces-docker-start.log)"
    (cd "$dcdir" && docker compose up -d) > /tmp/codespaces-docker-start.log 2>&1 || true
  fi
}

# Helper: find a package.json with "dev" script
find_package_with_dev() {
  # If user set override, use it
  if [ -n "${CODESPACES_FRONTEND_DIR:-}" ]; then
    # allow absolute or relative to workspace
    local candidate="$CODESPACES_FRONTEND_DIR"
    if [ ! -e "$candidate" ] && [ -e "$WORKSPACE_ROOT/$candidate" ]; then
      candidate="$WORKSPACE_ROOT/$candidate"
    fi
    if [ -f "$candidate/package.json" ]; then
      echo "$candidate/package.json"
      return 0
    fi
  fi

  # Search shallowly in workspace root (maxdepth 2) to avoid long scans
  local result
  result="$(find "$WORKSPACE_ROOT" -maxdepth 2 -type f -name package.json -print 2>/dev/null | while read -r p; do
    if grep -q '"dev"' "$p"; then
      echo "$p"
      break
    fi
  done)"
  printf '%s' "$result"
}

# Check if a TCP port is listening (best-effort)
port_listening() {
  local port="$1"
  if command -v ss >/dev/null 2>&1; then
    ss -ltn 2>/dev/null | grep -q ":$port" && return 0 || return 1
  fi
  if command -v netstat >/dev/null 2>&1; then
    netstat -ltn 2>/dev/null | grep -q ":$port" && return 0 || return 1
  fi
  # fallback try /proc/net/tcp (linux)
  if [ -r /proc/net/tcp ]; then
    grep -q ":$(printf '%04X' "$port")" /proc/net/tcp && return 0 || return 1
  fi
  return 1
}

# Start docker compose if applicable
start_docker_compose_if_present

# Start frontend dev server if applicable and not disabled
if [ -z "${CODESPACES_SKIP_FRONTEND:-}" ]; then
  pkg_json="$(find_package_with_dev)"
  if [ -n "$pkg_json" ]; then
    pkg_dir="$(dirname "$pkg_json")"
    # Check common ports (3000, 5173, 8000)
    if ! port_listening 3000 && ! port_listening 5173 && ! port_listening 8000; then
      echo "Codespaces startup: starting frontend dev in $pkg_dir (logs -> $HOME/.codespaces/dev-server.log)"
      (
        cd "$pkg_dir"
        # prefer npm ci for reproducibility if lockfile exists
        if [ -f package-lock.json ] || [ -f pnpm-lock.yaml ] || [ -f yarn.lock ]; then
          npm ci --silent || npm install --silent || true
        else
          npm install --silent || true
        fi
        # start dev server in background and capture output
        nohup sh -c "npm run dev" >"$HOME/.codespaces/dev-server.log" 2>&1 &
      )
    else
      echo "Codespaces startup: detected existing dev server on common ports; skipping auto-start"
    fi
  else
    # no package.json with dev found
    :
  fi
fi

# Short user-visible message in interactive shell
echo "Codespaces startup: init complete. Docker log: /tmp/codespaces-docker-start.log  Dev log: ~/.codespaces/dev-server.log"
