#!/usr/bin/env bash
# ~/.codespaces/startup.sh
# Idempotent startup script for Codespaces (safe to source every shell start).

# Only run interactively once per session
# (avoid running on non-interactive shells)
case "$-" in
  *i*) ;;
  *) return ;;
esac

# Prevent multiple re-runs in the same shell
if [ -n "$CODESPACES_STARTUP_HAS_RUN" ]; then
  return
fi
export CODESPACES_STARTUP_HAS_RUN=1

# Utility: find the workspace root
find_workspace_root() {
  # Common Codespaces mountpoints: /workspaces/<repo> OR /workspace
  if [ -d "/workspaces" ]; then
    # choose the first non-empty repo folder
    for d in /workspaces/*; do
      [ -d "$d" ] || continue
      # heuristic: must contain a .git or package.json or index.html
      if [ -e "$d/.git" ] || [ -e "$d/package.json" ] || [ -e "$d/index.html" ]; then
        echo "$d"
        return 0
      fi
    done
  fi
  if [ -d "/workspace" ]; then
    echo "/workspace"
    return 0
  fi
  # fallback to current working dir
  echo "$PWD"
  return 0
}

WORKSPACE_ROOT="$(find_workspace_root)"

# --------------- 1) Start docker-compose services if docker-compose.yml exists ---------------
if [ -f "$WORKSPACE_ROOT/.devcontainer/docker-compose.yml" ] || [ -f "$WORKSPACE_ROOT/docker-compose.yml" ]; then
  # prefer docker compose in repo .devcontainer then root
  if [ -f "$WORKSPACE_ROOT/.devcontainer/docker-compose.yml" ]; then
    DC_DIR="$WORKSPACE_ROOT/.devcontainer"
  else
    DC_DIR="$WORKSPACE_ROOT"
  fi

  # run docker compose up -d (idempotent)
  (cd "$DC_DIR" && command -v docker >/dev/null 2>&1 && docker compose up -d) >/tmp/codespaces-docker-start.log 2>&1 || true
fi

# --------------- 2) Start frontend dev server automatically (non-blocking) ---------------
# Heuristic: find a package.json with a dev script
start_frontend_dev_if_needed() {
  # Search workspace for a package.json that has "dev" script
  local pkg
  pkg="$(find "$WORKSPACE_ROOT" -maxdepth 2 -type f -name package.json -print0 2>/dev/null | xargs -0 -n1 | while read -r p; do
    if grep -q '"dev"' "$p"; then
      echo "$p"
      break
    fi
  done)"

  [ -z "$pkg" ] && return 0
  local pkg_dir
  pkg_dir="$(dirname "$pkg")"

  # check if server already listening on common ports (3000/5173/8000)
  is_listening() {
    # require ss (socket statistics) or netstat; tolerate absence
    command -v ss >/dev/null 2>&1 && ss -ltn | grep -q ":$1" && return 0 || true
    command -v netstat >/dev/null 2>&1 && netstat -ltn 2>/dev/null | grep -q ":$1" && return 0 || true
    return 1
  }

  # If package.json has `dev` and no common port in use, start dev
  if ! is_listening 3000 && ! is_listening 5173 && ! is_listening 8000; then
    # Start in background with nohup to avoid blocking the shell
    (
      cd "$pkg_dir"
      # ensure deps are installed (fast if already installed)
      if [ -f package-lock.json ] || [ -f pnpm-lock.yaml ] || [ -f yarn.lock ]; then
        npm ci --silent || npm install --silent || true
      else
        npm install --silent || true
      fi
      # Launch dev in background, redirect logs
      nohup sh -c "npm run dev" >"$HOME/.codespaces/dev-server.log" 2>&1 &
    )
  fi
}

start_frontend_dev_if_needed

# Optional: show a short message (only for interactive shells)
echo "Codespaces startup: checked Docker & frontend (logs: ~/.codespaces or /tmp/codespaces-docker-start.log)"
