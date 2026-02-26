#!/usr/bin/env bash
set -e

# Directory for codespaces scripts
mkdir -p "$HOME/.codespaces"

# Copy startup script (this repo must include startup.sh next to install.sh)
cp -f ./startup.sh "$HOME/.codespaces/startup.sh"
chmod +x "$HOME/.codespaces/startup.sh"

# Ensure .bashrc sources our codespaces startup bootstrap (idempotent)
BOOTSTRAP_LINE='[ -f "$HOME/.codespaces/startup.sh" ] && source "$HOME/.codespaces/startup.sh"'

# Add to .bashrc if not present
if ! grep -Fq "$BOOTSTRAP_LINE" "$HOME/.bashrc" 2>/dev/null; then
  printf "\n# codespaces: source per-session startup\n%s\n" "$BOOTSTRAP_LINE" >> "$HOME/.bashrc"
fi

echo "Dotfiles install: installed ~/.codespaces/startup.sh and hooked into .bashrc"
