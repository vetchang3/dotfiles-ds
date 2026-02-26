# Codespaces dotfiles (minimal)

This repository contains a minimal dotfiles setup to auto-start Docker Compose services
and a frontend `npm run dev` inside GitHub Codespaces.

**How it works**
- GitHub copies this repo into the codespace and runs `install.sh`.
- `install.sh` copies `startup.sh` to `~/.codespaces/startup.sh` and ensures it is sourced from `~/.bashrc`.
- On each interactive shell open, `startup.sh` runs once and:
  - starts `docker compose up -d` if it finds a docker-compose file,
  - starts `npm run dev` from the first package.json with a `dev` script (non-blocking),
  - logs outputs to `~/.codespaces/dev-server.log` and `/tmp/codespaces-docker-start.log`.

**Overrides**
- Set `CODESPACES_FRONTEND_DIR` to the relative path of your frontend dir (like `frontend`).
- Set `CODESPACES_SKIP_FRONTEND=1` to prevent auto-start of the frontend dev server.

**Security**
- Do not store secrets in this repo.
