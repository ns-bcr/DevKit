# DevKit

> Automated Ubuntu 26.04 LTS "Resolute Raccoon" development VM provisioning — batteries included.

Boot a bare Ubuntu Server and run a single script to equip it with a full-stack developer environment — behind an interactive menu or headless `--all` mode.

---

## Quick Start

```bash
# Download — or copy devkit.sh onto the machine
sudo bash devkit.sh

# Or skip the menu, install everything
sudo bash devkit.sh --all
```

## Components

| Category | What you get |
|----------|-------------|
| **Shell** | ZSH + Oh My Zsh (default shell) |
| **Containers** | Docker CE + Compose + Buildx, Portainer CE (web UI) |
| **JavaScript / TypeScript** | Node.js LTS (via NVM), Bun, 30+ global npm packages |
| **Python** | Python 3 + pipx, poetry, black, flake8, httpie |
| **PHP** | PHP 8.5 + OPcache + Composer |
| **Web servers** | Apache2 (port 80), Nginx (port 8080) |
| **Go** | Latest stable release from go.dev |
| **AI Agents** | Claude Code, OpenAI Codex CLI, OpenCode |
| **Dev tools** | GitHub CLI, Stripe CLI, Certbot, Java 21 LTS |
| **Security** | UFW firewall, fail2ban |

## Verification

Check what's installed without touching the system:

```bash
sudo bash devkit.sh --check
```

## Requirements

- Ubuntu 26.04 LTS (Resolute Raccoon)
- Root / `sudo` access
- Internet connection (fetches packages from official repos)

## File structure

```
DevKit/
├── devkit.sh         # Provisioning script
├── .gitignore
└── README.md
```

---
