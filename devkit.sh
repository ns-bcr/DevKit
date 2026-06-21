cat devkit.sh
#!/bin/bash
# =============================================================================
#  SETUP DEV VM — Ubuntu Server 26.04 LTS "Resolute Raccoon"
#  Script complet — Ahmed — Proxmox homelab
#
#  Stack disponible :
#  - Système    : ZSH + Oh My Zsh, outils CLI de base
#  - Conteneurs : Docker CE + Compose + Buildx, Portainer CE
#  - JS/TS      : Node.js LTS (via NVM), npm globals, Bun
#  - Python     : Python 3.14, pip, pipx, poetry, black, flake8, httpie
#  - PHP        : PHP 8.5 + Composer (OPcache bundlé dans php8.5-common)
#  - Web        : Apache2 (port 80) + Nginx (port 8080)
#  - Go         : Go 1.26 (version dynamique depuis go.dev)
#  - AI Agents  : Claude Code, OpenAI Codex CLI, OpenCode
#  - Outils     : GitHub CLI, Stripe CLI, Certbot, Java 21 LTS, git config
#  - Sécurité   : UFW (fail2ban inclus dans les outils de base)
#
#  Notes Ubuntu 26.04 (Resolute Raccoon) :
#  - Kernel 7.0 | systemd 259 (cgroup v2 UNIQUEMENT)
#  - PHP 8.5 dans les repos officiels Ubuntu (PPA Ondřej non requis)
#  - OPcache bundlé dans php8.5-common — pas de paquet séparé php8.5-opcache
#  - sudo-rs (rewrite Rust, drop-in replacement)
#  - containerd 2.x (Docker CE 29+ compatible)
#  - Python 3.14 | Go 1.26 | Node.js LTS via NVM
# =============================================================================

set -e

# ── Fix locale (évite les warnings perl/apt) ──────────────────────────────────
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export DEBIAN_FRONTEND=noninteractive

# ── Couleurs & helpers ────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
BOLD='\033[1m'
log()  { echo -e "${GREEN}[OK]${NC} $1"; }
info() { echo -e "${CYAN}[>>]${NC} $1"; }
warn() { echo -e "${YELLOW}[!!]${NC} $1"; }
step() {
  echo -e "\n${CYAN}============================================================${NC}"
  echo -e "${CYAN}  $1${NC}"
  echo -e "${CYAN}============================================================${NC}"
}

# =============================================================================
# MODE --check : vérifie l'installation sans rien modifier
# Usage : sudo bash devkit.sh --check
# =============================================================================
if [[ "${1:-}" == "--check" ]]; then

  DEV_USER="${SUDO_USER:-$USER}"
  DEV_HOME=$(getent passwd "$DEV_USER" | cut -d: -f6 2>/dev/null || echo "$HOME")
  IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "?")

  OK=0; WARN=0; FAIL=0

  chk() {
    local LABEL="$1"
    local CMD="$2"
    local VERSION
    VERSION=$(eval "$CMD" 2>/dev/null | head -1 | tr -d '\n')
    if [[ -n "$VERSION" ]]; then
      echo -e "  ${GREEN}[✓]${NC} ${BOLD}${LABEL}${NC} — ${VERSION}"
      ((++OK))
    else
      echo -e "  ${RED}[✗]${NC} ${BOLD}${LABEL}${NC} — non trouvé"
      ((++FAIL))
    fi
  }

  chk_service() {
    local LABEL="$1"
    local SERVICE="$2"
    local EXTRA="$3"
    if systemctl is-active --quiet "$SERVICE" 2>/dev/null; then
      echo -e "  ${GREEN}[✓]${NC} ${BOLD}${LABEL}${NC} — actif${EXTRA}"
      ((++OK))
    else
      echo -e "  ${RED}[✗]${NC} ${BOLD}${LABEL}${NC} — inactif ou absent"
      ((++FAIL))
    fi
  }

  chk_port() {
    local LABEL="$1"
    local PORT="$2"
    if ss -tlnp 2>/dev/null | grep -q ":${PORT} " || \
       netstat -tlnp 2>/dev/null | grep -q ":${PORT} "; then
      echo -e "  ${GREEN}[✓]${NC} ${BOLD}${LABEL}${NC} — port ${PORT} ouvert"
      ((++OK))
    else
      echo -e "  ${YELLOW}[~]${NC} ${BOLD}${LABEL}${NC} — port ${PORT} non détecté"
      ((++WARN))
    fi
  }

  echo ""
  echo -e "${BOLD}╔══════════════════════════════════════════════════════════════╗${NC}"
  echo -e "${BOLD}║  DEVKIT — Vérification de l'installation                     ║${NC}"
  echo -e "${BOLD}║  Serveur : $(hostname)   IP : ${IP}$(printf '%*s' $((28 - ${#IP} - ${#HOSTNAME})) '')║${NC}"
  echo -e "${BOLD}╚══════════════════════════════════════════════════════════════╝${NC}"

  # ── Système ────────────────────────────────────────────────────────────────
  echo -e "\n${CYAN}  SYSTÈME${NC}"
  chk "OS"      "lsb_release -d | cut -f2"
  chk "Kernel"  "uname -r"
  chk "ZSH"     "zsh --version"
  chk "Git"     "git --version"
  chk "Curl"    "curl --version | head -1"

  # ── Conteneurs ─────────────────────────────────────────────────────────────
  echo -e "\n${CYAN}  CONTENEURS${NC}"
  chk         "Docker"    "docker --version"
  chk         "Compose"   "docker compose version"
  chk_service "Docker svc" "docker" ""
  if docker ps 2>/dev/null | grep -q portainer; then
    echo -e "  ${GREEN}[✓]${NC} ${BOLD}Portainer${NC} — https://${IP}:9443"
    ((++OK))
  else
    echo -e "  ${RED}[✗]${NC} ${BOLD}Portainer${NC} — container absent"
    ((++FAIL))
  fi

  # ── Langages ───────────────────────────────────────────────────────────────
  echo -e "\n${CYAN}  LANGAGES${NC}"
  chk "Python"   "python3 --version"
  chk "pip"      "pip3 --version"
  chk "pipx"     "pipx --version"
  chk "Poetry"   "sudo -u $DEV_USER bash -c 'pipx run poetry --version 2>/dev/null || poetry --version 2>/dev/null || ~/.local/bin/poetry --version'"
  chk "PHP"      "php --version | head -1"
  chk "OPcache"  "php -m | grep -i opcache && echo 'actif'"
  chk "Composer" "composer --version"
  chk "Go"       "/usr/local/go/bin/go version"
  chk "Node"     "sudo -u $DEV_USER bash -c 'source \$HOME/.nvm/nvm.sh 2>/dev/null && node --version'"
  chk "npm"      "sudo -u $DEV_USER bash -c 'source \$HOME/.nvm/nvm.sh 2>/dev/null && npm --version'"
  chk "Bun"      "sudo -u $DEV_USER bash -c '\$HOME/.bun/bin/bun --version'"

  # ── Serveurs web ───────────────────────────────────────────────────────────
  echo -e "\n${CYAN}  SERVEURS WEB${NC}"
  chk         "Apache2"   "apache2 -v | head -1"
  chk_service "Apache svc" "apache2" " → http://${IP}:80"
  chk         "Nginx"     "nginx -v 2>&1"
  chk_service "Nginx svc"  "nginx"   " → http://${IP}:8080"

  # ── AI Agents ──────────────────────────────────────────────────────────────
  echo -e "\n${CYAN}  AI AGENTS${NC}"
  chk "Claude Code" "sudo -u $DEV_USER bash -c 'PATH=\$HOME/.local/bin:\$PATH claude --version 2>/dev/null || ls \$HOME/.local/bin/claude 2>/dev/null'"
  chk "Codex CLI"   "sudo -u $DEV_USER bash -c 'source \$HOME/.nvm/nvm.sh 2>/dev/null && codex --version 2>/dev/null || which codex'"
  chk "OpenCode"    "sudo -u $DEV_USER bash -c 'source \$HOME/.nvm/nvm.sh 2>/dev/null && opencode --version 2>/dev/null || which opencode'"

  # ── Outils dev ─────────────────────────────────────────────────────────────
  echo -e "\n${CYAN}  OUTILS DEV${NC}"
  chk "GitHub CLI"  "gh --version | head -1"
  chk "Stripe CLI"  "stripe --version"
  chk "Certbot"     "certbot --version"
  chk "Java 21"     "java --version | head -1"

  # ── Sécurité ───────────────────────────────────────────────────────────────
  echo -e "\n${CYAN}  SÉCURITÉ${NC}"
  chk_service "UFW"      "ufw"      ""
  if ufw status 2>/dev/null | grep -q "Status: active"; then
    echo -e "  ${GREEN}[✓]${NC} ${BOLD}UFW actif${NC} — règles en place"
    ((++OK))
  else
    echo -e "  ${YELLOW}[~]${NC} ${BOLD}UFW${NC} — inactif"
    ((++WARN))
  fi
  chk_service "fail2ban" "fail2ban" ""

  # ── Rapport ────────────────────────────────────────────────────────────────
  TOTAL=$((OK + WARN + FAIL))
  echo ""
  echo -e "${BOLD}──────────────────────────────────────────────────────────────${NC}"
  echo -e "  ${GREEN}Installés  : $OK${NC}   ${YELLOW}Avertissements : $WARN${NC}   ${RED}Manquants : $FAIL${NC}   Total : $TOTAL"
  echo -e "${BOLD}──────────────────────────────────────────────────────────────${NC}"
  echo ""

  if [[ $FAIL -eq 0 && $WARN -eq 0 ]]; then
    echo -e "  ${GREEN}${BOLD}Installation complète et fonctionnelle.${NC}"
  elif [[ $FAIL -eq 0 ]]; then
    echo -e "  ${YELLOW}${BOLD}Installation OK — quelques points à vérifier manuellement.${NC}"
  else
    echo -e "  ${RED}${BOLD}$FAIL composant(s) manquant(s). Relance devkit.sh pour les installer.${NC}"
  fi
  echo ""
  exit 0
fi

# ── Vérification Ubuntu 26.04 ─────────────────────────────────────────────────
if ! grep -q "26.04" /etc/os-release 2>/dev/null; then
  warn "Ce script cible Ubuntu 26.04 LTS (Resolute Raccoon). Continuer quand même ? (y/N)"
  read -r REPLY; [[ "$REPLY" =~ ^[Yy]$ ]] || exit 1
fi

CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")
info "Ubuntu 26.04 — codename : $CODENAME"

# ── Vérification root ─────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}[ERR]${NC} Lance avec sudo : sudo bash setup-dev-vm.sh"
  exit 1
fi

# ── Utilisateur dev (non-root) ────────────────────────────────────────────────
DEV_USER="${SUDO_USER:-$USER}"
DEV_HOME=$(getent passwd "$DEV_USER" | cut -d: -f6)
info "Utilisateur dev : $DEV_USER (home : $DEV_HOME)"

# =============================================================================
# MODE --all : installe tout sans passer par le menu
# Usage : sudo bash devkit.sh --all
# =============================================================================
if [[ "${1:-}" == "--all" ]]; then
  CHOICES=$'SYSTEM\nBASE\nZSH\nDOCKER\nPORTAINER\nNODE\nNPM\nBUN\nPYTHON\nPHP\nAPACHE\nNGINX\nGO\nAI\nGHCLI\nJAVA\nUFW'
  info "Mode --all : installation complète (17 composants)"
else

# =============================================================================
# MENU INTERACTIF — Sélection des composants
# =============================================================================

# whiptail est disponible par défaut sur Ubuntu Server
if ! command -v whiptail &>/dev/null; then
  apt-get install -y whiptail -q
fi

# S'assurer que TERM est défini (nécessaire pour whiptail via SSH/sudo)
export TERM="${TERM:-xterm}"

# Détecter la taille du terminal pour éviter le débordement
TERM_H=$(tput lines 2>/dev/null || echo 40)
TERM_W=$(tput cols  2>/dev/null || echo 80)
# Laisser au moins 2 lignes de marge en haut/bas et 4 colonnes
DLG_H=$(( TERM_H > 6  ? TERM_H - 2  : 24 ))
DLG_W=$(( TERM_W > 14 ? TERM_W - 4  : 72 ))
# Hauteur de la liste = taille fenêtre moins l'overhead (titre + texte + boutons ~8)
LIST_H=$(( DLG_H - 8 > 4 ? DLG_H - 8 : 4 ))

# Écrire la TUI directement sur /dev/tty — plus fiable que le swap de fd 3>&1 1>&2 2>&3
_TMP=$(mktemp /tmp/devkit-choices.XXXXXX)
if ! whiptail \
  --title "Setup Dev VM — Ubuntu 26.04 LTS" \
  --separate-output \
  --checklist \
  $'\nSélectionne les composants à installer.\n[Espace] cocher/décocher  [Entrée] valider\n' \
  "$DLG_H" "$DLG_W" "$LIST_H" \
  "SYSTEM"    "Mise à jour système (apt upgrade)"            ON \
  "BASE"      "Outils de base (curl, git, vim, build...)"    ON \
  "ZSH"       "ZSH + Oh My Zsh"                              ON \
  "DOCKER"    "Docker CE + Compose + Buildx"                 ON \
  "PORTAINER" "Portainer CE (UI Web Docker)"                 ON \
  "NODE"      "Node.js LTS via NVM"                          ON \
  "NPM"       "Packages npm globaux (Next, Prisma, Expo...)" ON \
  "BUN"       "Bun (runtime JS rapide)"                      ON \
  "PYTHON"    "Python 3 + pip + pipx + poetry"               ON \
  "PHP"       "PHP 8.5 + Composer"                           ON \
  "APACHE"    "Apache2 (port 80)"                            ON \
  "NGINX"     "Nginx (port 8080)"                            ON \
  "GO"        "Go (version dynamique depuis go.dev)"         ON \
  "AI"        "AI Agents (Claude Code, Codex, OpenCode)"     ON \
  "GHCLI"     "GitHub CLI + Stripe CLI + Certbot"            ON \
  "JAVA"      "Java 21 LTS (OpenJDK)"                        ON \
  "UFW"       "Pare-feu UFW"                                 ON \
  > "$_TMP" 2>/dev/tty; then
  rm -f "$_TMP"
  echo "Installation annulée."
  exit 0
fi
CHOICES=$(cat "$_TMP")
rm -f "$_TMP"

fi   # fin du bloc --all / menu

# Parsing : --separate-output produit une ligne par item sélectionné, sans guillemets
# grep -qx cherche une correspondance exacte sur la ligne entière
is_on() { echo "$CHOICES" | grep -qx "$1"; }

INSTALL_SYSTEM=false;    { is_on "SYSTEM"    && INSTALL_SYSTEM=true;    } || true
INSTALL_BASE=false;      { is_on "BASE"      && INSTALL_BASE=true;      } || true
INSTALL_ZSH=false;       { is_on "ZSH"       && INSTALL_ZSH=true;       } || true
INSTALL_DOCKER=false;    { is_on "DOCKER"    && INSTALL_DOCKER=true;    } || true
INSTALL_PORTAINER=false; { is_on "PORTAINER" && INSTALL_PORTAINER=true; } || true
INSTALL_NODE=false;      { is_on "NODE"      && INSTALL_NODE=true;      } || true
INSTALL_NPM=false;       { is_on "NPM"       && INSTALL_NPM=true;       } || true
INSTALL_BUN=false;       { is_on "BUN"       && INSTALL_BUN=true;       } || true
INSTALL_PYTHON=false;    { is_on "PYTHON"    && INSTALL_PYTHON=true;    } || true
INSTALL_PHP=false;       { is_on "PHP"       && INSTALL_PHP=true;       } || true
INSTALL_APACHE=false;    { is_on "APACHE"    && INSTALL_APACHE=true;    } || true
INSTALL_NGINX=false;     { is_on "NGINX"     && INSTALL_NGINX=true;     } || true
INSTALL_GO=false;        { is_on "GO"        && INSTALL_GO=true;        } || true
INSTALL_AI=false;        { is_on "AI"        && INSTALL_AI=true;        } || true
INSTALL_GHCLI=false;     { is_on "GHCLI"     && INSTALL_GHCLI=true;     } || true
INSTALL_JAVA=false;      { is_on "JAVA"      && INSTALL_JAVA=true;      } || true
INSTALL_UFW=false;       { is_on "UFW"       && INSTALL_UFW=true;       } || true

# Résumé avant de démarrer
echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  Composants sélectionnés                                     ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
for item in \
  "SYSTEM:Mise à jour système" \
  "BASE:Outils de base" \
  "ZSH:ZSH + Oh My Zsh" \
  "DOCKER:Docker CE + Compose" \
  "PORTAINER:Portainer CE" \
  "NODE:Node.js LTS (NVM)" \
  "NPM:Packages npm globaux" \
  "BUN:Bun" \
  "PYTHON:Python 3 + pipx" \
  "PHP:PHP 8.5 + Composer" \
  "APACHE:Apache2" \
  "NGINX:Nginx" \
  "GO:Go" \
  "AI:AI Agents" \
  "GHCLI:GitHub CLI + Stripe + Certbot" \
  "JAVA:Java 21 LTS" \
  "UFW:Pare-feu UFW"; do
  KEY="${item%%:*}"
  LABEL="${item#*:}"
  VAL=$(eval echo "\$INSTALL_$KEY")
  if [[ "$VAL" == "true" ]]; then
    echo -e "  ${GREEN}[✓]${NC} $LABEL"
  else
    echo -e "  ${RED}[✗]${NC} $LABEL"
  fi
done
echo ""
echo -e "${YELLOW}Démarrage dans 3 secondes... (Ctrl+C pour annuler)${NC}"
sleep 3

# =============================================================================
# 1. MISE À JOUR SYSTÈME
# =============================================================================
if [[ "$INSTALL_SYSTEM" == "true" ]]; then
  step "1 — Mise à jour du système"
  apt-get update -y
  apt-get install -y locales
  locale-gen en_US.UTF-8
  update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
  apt-get upgrade -y
  apt-get dist-upgrade -y
  apt-get autoremove -y
  apt-get autoclean -y
  log "Système à jour (kernel $(uname -r))"
fi

# =============================================================================
# 2. UTILITAIRES DE BASE
# =============================================================================
if [[ "$INSTALL_BASE" == "true" ]]; then
  step "2 — Outils de base"
  apt-get install -y \
    curl wget git htop vim nano unzip zip \
    build-essential make cmake gcc g++ pkg-config \
    ca-certificates gnupg lsb-release software-properties-common apt-transport-https \
    net-tools nmap traceroute dnsutils iputils-ping iproute2 \
    jq tree tmux screen \
    openssl openssh-server ufw fail2ban \
    ffmpeg imagemagick \
    rsync \
    bash-completion zsh \
    sqlite3 libsqlite3-dev \
    redis-tools \
    tcpdump netcat-openbsd socat \
    mc gpg
  log "Utilitaires de base installés"
fi

# =============================================================================
# 3. ZSH + OH MY ZSH
# =============================================================================
if [[ "$INSTALL_ZSH" == "true" ]]; then
  step "3 — ZSH + Oh My Zsh"
  sudo -u "$DEV_USER" sh -c \
    'curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh | sh --unattended' || \
    warn "Oh My Zsh : déjà présent ou erreur réseau — on continue."
  chsh -s "$(which zsh)" "$DEV_USER"
  log "ZSH installé — shell par défaut : $DEV_USER"
fi

# =============================================================================
# 4. DOCKER ENGINE + DOCKER COMPOSE
# =============================================================================
if [[ "$INSTALL_DOCKER" == "true" ]]; then
  step "4 — Docker Engine (CE + Compose + Buildx)"
  apt-get remove -y docker.io docker-compose docker-compose-v2 docker-doc podman-docker 2>/dev/null || true
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
    https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null
  apt-get update -y
  apt-get install -y \
    docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin
  usermod -aG docker "$DEV_USER"
  systemctl enable docker
  systemctl start docker
  log "Docker $(docker --version | cut -d' ' -f3 | tr -d ',') + Compose $(docker compose version | cut -d' ' -f4)"
fi

# =============================================================================
# 5. PORTAINER CE
# =============================================================================
if [[ "$INSTALL_PORTAINER" == "true" ]]; then
  step "5 — Portainer CE"
  docker volume create portainer_data 2>/dev/null || true
  docker rm -f portainer 2>/dev/null || true
  docker run -d \
    --name portainer \
    --restart=always \
    -p 8000:8000 -p 9443:9443 \
    -v /var/run/docker.sock:/var/run/docker.sock \
    -v portainer_data:/data \
    portainer/portainer-ce:latest
  log "Portainer → https://$(hostname -I | awk '{print $1}'):9443"
fi

# =============================================================================
# 6. NODE.JS via NVM
# =============================================================================
if [[ "$INSTALL_NODE" == "true" ]]; then
  step "6 — Node.js via NVM"
  NVM_VERSION=$(curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest \
    | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/' 2>/dev/null || echo "0.40.3")
  info "NVM v${NVM_VERSION}"
  sudo -u "$DEV_USER" bash -c \
    "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh | bash"
  export NVM_DIR="$DEV_HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  sudo -u "$DEV_USER" bash -c \
    'export NVM_DIR="$HOME/.nvm"; source "$NVM_DIR/nvm.sh"
     nvm install --lts
     nvm alias default node
     nvm use --lts'
  grep -q 'NVM_DIR' "$DEV_HOME/.zshrc" 2>/dev/null || cat >> "$DEV_HOME/.zshrc" << 'EOF'

# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
EOF
  log "Node.js LTS + npm installés via NVM"
fi

# =============================================================================
# 7. PACKAGES NPM GLOBAUX
# =============================================================================
if [[ "$INSTALL_NPM" == "true" ]]; then
  step "7 — Packages npm globaux"
  sudo -u "$DEV_USER" bash << 'NPMEOF'
export NVM_DIR="$HOME/.nvm"
source "$NVM_DIR/nvm.sh"
npm install -g npm@latest yarn pnpm
npm install -g typescript tsx ts-node tsup tsc-watch @swc/cli @swc/core
npm install -g create-next-app @vue/cli @angular/cli vite turbo create-t3-app
npm install -g drizzle-kit prisma shadcn
npm install -g @biomejs/biome eslint prettier
npm install -g vitest jest @playwright/test
npm install -g husky lint-staged commitizen @commitlint/cli @commitlint/config-conventional release-it standard-version
npm install -g pm2 nodemon concurrently cross-env dotenv-cli rimraf npm-check-updates depcheck http-server serve
npm install -g esbuild rollup
npm install -g vercel netlify-cli wrangler @railway/cli supabase
npm install -g @expo/cli eas-cli react-devtools
NPMEOF
  log "Packages npm globaux installés"
fi

# =============================================================================
# 8. BUN
# =============================================================================
if [[ "$INSTALL_BUN" == "true" ]]; then
  step "8 — Bun"
  sudo -u "$DEV_USER" bash -c 'curl -fsSL https://bun.sh/install | bash'
  grep -q 'BUN_INSTALL' "$DEV_HOME/.zshrc" 2>/dev/null || cat >> "$DEV_HOME/.zshrc" << 'EOF'

# Bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
EOF
  grep -q 'BUN_INSTALL' "$DEV_HOME/.bashrc" 2>/dev/null || cat >> "$DEV_HOME/.bashrc" << 'EOF'

# Bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
EOF
  log "Bun installé"
fi

# =============================================================================
# 9. PYTHON 3 + PIP + PIPX
# =============================================================================
if [[ "$INSTALL_PYTHON" == "true" ]]; then
  step "9 — Python 3 + pip + outils"
  apt-get install -y python3 python3-pip python3-venv python3-dev python3-full pipx
  sudo -u "$DEV_USER" pipx ensurepath
  sudo -u "$DEV_USER" bash << 'PYEOF'
for pkg in poetry black flake8 httpie; do
  pipx install "$pkg" 2>/dev/null || pipx upgrade "$pkg" 2>/dev/null || true
done
PYEOF
  PIPX_LINE='export PATH="$HOME/.local/bin:$PATH"'
  grep -qxF "$PIPX_LINE" "$DEV_HOME/.zshrc"  2>/dev/null || \
    echo -e "\n# pipx\n$PIPX_LINE" >> "$DEV_HOME/.zshrc"
  grep -qxF "$PIPX_LINE" "$DEV_HOME/.bashrc" 2>/dev/null || \
    echo -e "\n# pipx\n$PIPX_LINE" >> "$DEV_HOME/.bashrc"
  log "Python $(python3 --version | cut -d' ' -f2) + pipx + outils installés"
fi

# =============================================================================
# 10. PHP 8.5 + COMPOSER
#     OPcache bundlé dans php8.5-common — pas de paquet php8.5-opcache séparé.
# =============================================================================
if [[ "$INSTALL_PHP" == "true" ]]; then
  step "10 — PHP 8.5 + Composer"
  apt-get install -y \
    php8.5 php8.5-cli php8.5-fpm \
    php8.5-curl php8.5-mbstring php8.5-xml php8.5-zip \
    php8.5-gd php8.5-intl php8.5-bcmath \
    php8.5-sqlite3 php8.5-xdebug \
    libapache2-mod-php8.5
  php -m | grep -i opcache && log "OPcache actif" || warn "OPcache non détecté — vérifier php8.5-common"
  php -r "copy('https://getcomposer.org/installer', '/tmp/composer-setup.php');"
  EXPECTED=$(php -r "echo file_get_contents('https://composer.github.io/installer.sig');")
  ACTUAL=$(php -r "echo hash_file('sha384', '/tmp/composer-setup.php');")
  if [ "$EXPECTED" != "$ACTUAL" ]; then
    warn "Checksum Composer inattendu — installation quand même"
  fi
  php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer
  rm -f /tmp/composer-setup.php
  log "PHP $(php --version | head -1 | cut -d' ' -f2) + Composer $(composer --version | cut -d' ' -f3)"
fi

# =============================================================================
# 11. APACHE2
# =============================================================================
if [[ "$INSTALL_APACHE" == "true" ]]; then
  step "11 — Apache2"
  apt-get install -y apache2
  a2enmod rewrite ssl headers deflate expires proxy proxy_http php8.5
  cat > /etc/apache2/conf-available/dev-options.conf << 'APACHECONF'
ServerTokens Prod
ServerSignature Off
TraceEnable Off
Options -Indexes
APACHECONF
  a2enconf dev-options
  systemctl enable apache2
  systemctl restart apache2
  log "Apache2 $(apache2 -v | head -1 | cut -d'/' -f2 | cut -d' ' -f1) — port 80"
fi

# =============================================================================
# 12. NGINX (port 8080 pour coexister avec Apache)
# =============================================================================
if [[ "$INSTALL_NGINX" == "true" ]]; then
  step "12 — Nginx"
  apt-get install -y nginx
  if grep -q "listen 80 default_server" /etc/nginx/sites-available/default 2>/dev/null; then
    sed -i 's/listen 80 default_server;/listen 8080 default_server;/' \
      /etc/nginx/sites-available/default
    sed -i 's/listen \[::\]:80 default_server;/listen [::]:8080 default_server;/' \
      /etc/nginx/sites-available/default
  fi
  systemctl enable nginx
  systemctl restart nginx
  log "Nginx $(nginx -v 2>&1 | cut -d'/' -f2) — port 8080"
fi

# =============================================================================
# 13. GO (version dynamique depuis go.dev)
# =============================================================================
if [[ "$INSTALL_GO" == "true" ]]; then
  step "13 — Go"
  GO_VERSION=$(curl -fsSL "https://go.dev/dl/?mode=json" \
    | grep -o '"version":"go[^"]*"' | head -1 | grep -o '[0-9][^"]*' || echo "1.26.0")
  info "Go ${GO_VERSION}"
  wget -q "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -O "/tmp/go.tar.gz"
  rm -rf /usr/local/go
  tar -C /usr/local -xzf "/tmp/go.tar.gz"
  rm -f "/tmp/go.tar.gz"
  grep -q "/usr/local/go/bin" "$DEV_HOME/.zshrc" 2>/dev/null || cat >> "$DEV_HOME/.zshrc" << 'EOF'

# Go
export PATH=$PATH:/usr/local/go/bin
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin
EOF
  grep -q "/usr/local/go/bin" "$DEV_HOME/.bashrc" 2>/dev/null || cat >> "$DEV_HOME/.bashrc" << 'EOF'

# Go
export PATH=$PATH:/usr/local/go/bin
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin
EOF
  log "Go ${GO_VERSION} installé"
fi

# =============================================================================
# 14. AI CODING AGENTS
# =============================================================================
if [[ "$INSTALL_AI" == "true" ]]; then
  step "14 — AI Agents (Claude Code, Codex, OpenCode)"
  info "Claude Code..."
  sudo -u "$DEV_USER" bash -c 'curl -fsSL https://claude.ai/install.sh | bash' || \
    warn "Claude Code : relance manuellement → curl -fsSL https://claude.ai/install.sh | bash"
  info "Codex CLI + OpenCode..."
  sudo -u "$DEV_USER" bash -c \
    'export NVM_DIR="$HOME/.nvm"; source "$NVM_DIR/nvm.sh"
     npm install -g @openai/codex
     npm install -g opencode-ai@latest'
  log "AI Agents installés"
fi

# =============================================================================
# 15. GITHUB CLI + STRIPE CLI + CERTBOT
# =============================================================================
if [[ "$INSTALL_GHCLI" == "true" ]]; then
  step "15 — GitHub CLI + Stripe CLI + Certbot"
  info "GitHub CLI..."
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | gpg --dearmor -o /usr/share/keyrings/githubcli-archive-keyring.gpg
  chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] \
    https://cli.github.com/packages stable main" \
    | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
  apt-get update -y && apt-get install -y gh
  info "Stripe CLI..."
  curl -s https://packages.stripe.dev/api/security/keypair/stripe-cli-gpg/public \
    | gpg --dearmor | tee /usr/share/keyrings/stripe.gpg > /dev/null
  echo "deb [signed-by=/usr/share/keyrings/stripe.gpg] \
    https://packages.stripe.dev/stripe-cli-debian-local stable main" \
    | tee /etc/apt/sources.list.d/stripe.list
  apt-get update -y && apt-get install -y stripe
  info "Certbot..."
  apt-get install -y certbot python3-certbot-apache python3-certbot-nginx
  log "GitHub CLI + Stripe CLI + Certbot installés"
fi

# =============================================================================
# 16. JAVA 21 LTS
# =============================================================================
if [[ "$INSTALL_JAVA" == "true" ]]; then
  step "16 — Java 21 LTS (OpenJDK)"
  apt-get install -y openjdk-21-jdk
  grep -q "JAVA_HOME" "$DEV_HOME/.zshrc" 2>/dev/null || cat >> "$DEV_HOME/.zshrc" << 'EOF'

# Java (Android / Expo)
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export PATH="$PATH:$JAVA_HOME/bin"
EOF
  log "Java $(java -version 2>&1 | head -1) installé"
fi

# =============================================================================
# CONFIG GIT GLOBALE (si git est disponible)
# =============================================================================
if command -v git &>/dev/null; then
  sudo -u "$DEV_USER" git config --global init.defaultBranch main
  sudo -u "$DEV_USER" git config --global core.autocrlf input
  sudo -u "$DEV_USER" git config --global pull.rebase false
fi

# =============================================================================
# PARE-FEU UFW
# =============================================================================
if [[ "$INSTALL_UFW" == "true" ]]; then
  step "UFW — Pare-feu"
  ufw --force reset
  ufw default deny incoming
  ufw default allow outgoing
  for port in 22 80 443 8080 9443 3000 3001 4000 5000 8000; do
    ufw allow ${port}/tcp
  done
  ufw --force enable
  log "UFW configuré"
fi

# =============================================================================
# FIX DROITS HOME
# =============================================================================
chown -R "$DEV_USER:$DEV_USER" "$DEV_HOME"

# =============================================================================
# RÉCAPITULATIF
# =============================================================================
IP=$(hostname -I | awk '{print $1}')
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  INSTALLATION TERMINÉE — Ubuntu 26.04 LTS Resolute Raccoon  ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}  OS & KERNEL${NC}"
echo "  $(lsb_release -d | cut -f2) — kernel $(uname -r)"
echo ""

if [[ "$INSTALL_PYTHON" == "true" ]]; then
  echo -e "${CYAN}  LANGAGES${NC}"
  echo "  Python  : $(python3 --version 2>&1)"
fi
if [[ "$INSTALL_PHP" == "true" ]]; then
  echo "  PHP     : $(php --version | head -1 | cut -d' ' -f1-2)"
fi
if [[ "$INSTALL_GO" == "true" ]]; then
  echo "  Go      : $(/usr/local/go/bin/go version 2>/dev/null | cut -d' ' -f3)"
fi
if [[ "$INSTALL_NODE" == "true" ]]; then
  echo "  Node    : via NVM (source ~/.zshrc puis : nvm use --lts)"
fi
if [[ "$INSTALL_BUN" == "true" ]]; then
  echo "  Bun     : ~/.bun/bin/bun"
fi

if [[ "$INSTALL_DOCKER" == "true" ]]; then
  echo ""
  echo -e "${CYAN}  CONTENEURS${NC}"
  echo "  Docker  : $(docker --version)"
  echo "  Compose : $(docker compose version)"
fi
if [[ "$INSTALL_PORTAINER" == "true" ]]; then
  echo "  Portainer : https://${IP}:9443"
fi

if [[ "$INSTALL_APACHE" == "true" ]] || [[ "$INSTALL_NGINX" == "true" ]]; then
  echo ""
  echo -e "${CYAN}  SERVEURS WEB${NC}"
  [[ "$INSTALL_APACHE" == "true" ]] && echo "  Apache2 : http://${IP}:80"
  [[ "$INSTALL_NGINX"  == "true" ]] && echo "  Nginx   : http://${IP}:8080"
fi

if [[ "$INSTALL_AI" == "true" ]]; then
  echo ""
  echo -e "${CYAN}  AI AGENTS${NC}"
  echo "  claude    → Claude Code (Anthropic)"
  echo "  codex     → OpenAI Codex CLI"
  echo "  opencode  → OpenCode (multi-modèle)"
fi

echo ""
echo -e "${YELLOW}  ⚠ ACTIONS MANUELLES REQUISES${NC}"
echo "  1. Déconnecte / reconnecte-toi (groupe docker + PATH actifs)"
echo "  2. git config --global user.name  'Ton Nom'"
echo "     git config --global user.email 'ton@email.com'"
[[ "$INSTALL_GHCLI" == "true" ]] && echo "  3. gh auth login && stripe login"
[[ "$INSTALL_AI" == "true" ]]    && echo "  4. claude login | codex auth | opencode /connect"
[[ "$INSTALL_NPM" == "true" ]]   && echo "  5. eas login (Expo EAS)"
echo ""
echo -e "${GREEN}  → sudo reboot recommandé${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"