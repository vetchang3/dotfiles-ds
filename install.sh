#!/usr/bin/env bash
set -euo pipefail

# Dotfiles install script for GitHub Codespaces
# Copies startup.sh to ~/.codespaces/startup.sh and ensures it's sourced from .bashrc

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STARTUP_SRC="$DOTFILES_DIR/startup.sh"
STARTUP_DEST="$HOME/.codespaces/startup.sh"

echo "Dotfiles: installing Codespaces startup script..."

mkdir -p "$HOME/.codespaces"
cp -f "$STARTUP_SRC" "$STARTUP_DEST"
chmod +x "$STARTUP_DEST"

BOOTSTRAP_LINE='[ -f "$HOME/.codespaces/startup.sh" ] && source "$HOME/.codespaces/startup.sh"'

# Add to .bashrc if missing (only add for Codespaces env)
if [ -n "${CODESPACES:-}" ] || grep -q "/workspaces\|/workspace" <<< "$PWD"; then
  if ! grep -Fq "$BOOTSTRAP_LINE" "$HOME/.bashrc" 2>/dev/null ; then
    printf "\n# codespaces: source per-session startup\n%s\n" "$BOOTSTRAP_LINE" >> "$HOME/.bashrc"
    echo "-> Appended bootstrap line to ~/.bashrc"
  else
    echo "-> Bootstrap already present in ~/.bashrc"
  fi
else
  echo "-> Not in Codespaces environment; skipping .bashrc modification"
fi

echo "Dotfiles: installation complete. Startup script copied to $STARTUP_DEST"
