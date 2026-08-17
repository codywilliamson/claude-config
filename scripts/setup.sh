#!/usr/bin/env bash
set -euo pipefail

# first-time setup for claude-config
# detects os, checks prerequisites, finds obsidian vault, generates env, runs first sync
#
# usage:
#   curl -fsSL https://raw.githubusercontent.com/codywilliamson/claude-config/main/scripts/setup.sh | bash
#   — or —
#   git clone https://github.com/codywilliamson/claude-config.git ~/dev/claude-config
#   cd ~/dev/claude-config && bash scripts/setup.sh

# ── helpers ──────────────────────────────────────────────────────

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()    { printf "${BLUE}→${NC} %s\n" "$1"; }
ok()      { printf "${GREEN}✓${NC} %s\n" "$1"; }
warn()    { printf "${YELLOW}!${NC} %s\n" "$1"; }
err()     { printf "${RED}✗${NC} %s\n" "$1" >&2; }
header()  { printf "\n${BOLD}${CYAN}%s${NC}\n" "$1"; }
prompt()  { printf "${BOLD}? ${NC}%s " "$1"; }

# ── detect os & platform ────────────────────────────────────────

detect_platform() {
  local kernel
  kernel="$(uname -s)"

  case "$kernel" in
    Linux*)
      if grep -qi microsoft /proc/version 2>/dev/null; then
        PLATFORM="wsl"
        OS_DISPLAY="WSL (Windows Subsystem for Linux)"
      else
        PLATFORM="linux"
        # detect distro
        if [ -f /etc/os-release ]; then
          . /etc/os-release
          OS_DISPLAY="Linux ($NAME)"
        else
          OS_DISPLAY="Linux"
        fi
      fi
      ;;
    Darwin*)
      PLATFORM="macos"
      OS_DISPLAY="macOS $(sw_vers -productVersion 2>/dev/null || echo '')"
      ;;
    MINGW*|MSYS*|CYGWIN*)
      PLATFORM="windows"
      OS_DISPLAY="Windows (Git Bash / MSYS)"
      ;;
    *)
      PLATFORM="unknown"
      OS_DISPLAY="$kernel (unknown)"
      ;;
  esac
}

# ── detect shell ────────────────────────────────────────────────

detect_shell() {
  CURRENT_SHELL="$(basename "${SHELL:-unknown}")"
  case "$CURRENT_SHELL" in
    zsh)  SHELL_RC="$HOME/.zshrc" ;;
    bash) SHELL_RC="$HOME/.bashrc" ;;
    fish) SHELL_RC="$HOME/.config/fish/config.fish" ;;
    *)    SHELL_RC="$HOME/.profile" ;;
  esac
}

# ── prerequisite checks ────────────────────────────────────────

check_prerequisites() {
  header "checking prerequisites"

  local missing=()

  # required
  for cmd in git; do
    if command -v "$cmd" &>/dev/null; then
      ok "$cmd $(${cmd} --version 2>&1 | head -1 | grep -oP '[\d]+\.[\d]+\.[\d]+' | head -1)"
    else
      err "$cmd not found"
      missing+=("$cmd")
    fi
  done

  # recommended
  for cmd in node pnpm claude; do
    if command -v "$cmd" &>/dev/null; then
      local ver
      case "$cmd" in
        node)   ver="$(node --version 2>/dev/null)" ;;
        pnpm)   ver="$(pnpm --version 2>/dev/null)" ;;
        claude) ver="$(claude --version 2>/dev/null || echo 'installed')" ;;
      esac
      ok "$cmd $ver"
    else
      warn "$cmd not found (recommended)"
    fi
  done

  # sync.mjs runs on node — hard requirement, not just recommended
  if ! command -v node &>/dev/null; then
    err "node not found — scripts/sync.mjs needs it"
    err "  claude code installs via npm, so node is usually already present"
    missing+=("node")
  fi

  if [ ${#missing[@]} -gt 0 ]; then
    err "missing required tools: ${missing[*]}"
    err "install them and re-run setup"
    exit 1
  fi
}

# ── find obsidian vault ─────────────────────────────────────────

find_obsidian_vault() {
  header "looking for obsidian vault"

  local candidates=()

  # common vault locations
  local search_dirs=(
    "$HOME/dev/notes"
    "$HOME/Notes"
    "$HOME/notes"
    "$HOME/Documents"
    "$HOME/Documents/Notes"
    "$HOME/Documents/Obsidian"
    "$HOME/Obsidian"
    "$HOME/vaults"
  )

  for dir in "${search_dirs[@]}"; do
    if [ -d "$dir" ]; then
      # look for .obsidian dirs (indicates an obsidian vault)
      while IFS= read -r -d '' vault; do
        candidates+=("$(dirname "$vault")")
      done < <(find "$dir" -maxdepth 3 -name ".obsidian" -type d -print0 2>/dev/null)
    fi
  done

  if [ ${#candidates[@]} -eq 0 ]; then
    warn "no obsidian vault found automatically"
    prompt "enter your obsidian vault path (or press enter to skip):"
    read -r vault_input
    if [ -n "$vault_input" ]; then
      vault_input="${vault_input/#\~/$HOME}"
      if [ -d "$vault_input" ]; then
        WIKI_VAULT_PATH="$vault_input"
        ok "using vault: $WIKI_VAULT_PATH"
      else
        warn "path doesn't exist — skipping wiki vault config"
        WIKI_VAULT_PATH=""
      fi
    else
      WIKI_VAULT_PATH=""
      warn "skipped — you can set WIKI_VAULT_PATH later in .env.local"
    fi
  elif [ ${#candidates[@]} -eq 1 ]; then
    WIKI_VAULT_PATH="${candidates[0]}"
    ok "found vault: $WIKI_VAULT_PATH"
    prompt "use this vault? [Y/n]"
    read -r confirm
    if [[ "$confirm" =~ ^[Nn] ]]; then
      prompt "enter your obsidian vault path:"
      read -r vault_input
      vault_input="${vault_input/#\~/$HOME}"
      WIKI_VAULT_PATH="$vault_input"
    fi
  else
    info "found ${#candidates[@]} vaults:"
    for i in "${!candidates[@]}"; do
      printf "  ${BOLD}%d)${NC} %s\n" "$((i + 1))" "${candidates[$i]}"
    done
    prompt "pick one (number) or enter a custom path:"
    read -r choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#candidates[@]}" ]; then
      WIKI_VAULT_PATH="${candidates[$((choice - 1))]}"
    else
      choice="${choice/#\~/$HOME}"
      WIKI_VAULT_PATH="$choice"
    fi
    ok "using vault: $WIKI_VAULT_PATH"
  fi
}

# ── ensure repo is cloned ──────────────────────────────────────

ensure_repo() {
  header "checking claude-config repo"

  REPO_URL="https://github.com/codywilliamson/claude-config.git"

  # if we're running from inside the repo already, use that
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  CANDIDATE_REPO="$(dirname "$SCRIPT_DIR")"

  if [ -f "$CANDIDATE_REPO/CLAUDE.md" ] && [ -d "$CANDIDATE_REPO/.git" ]; then
    REPO_DIR="$CANDIDATE_REPO"
    ok "running from repo: $REPO_DIR"
    return
  fi

  # otherwise check default location
  REPO_DIR="${CLAUDE_CONFIG_REPO:-$HOME/dev/claude-config}"

  if [ -d "$REPO_DIR/.git" ]; then
    ok "repo exists at $REPO_DIR"
    info "pulling latest..."
    git -C "$REPO_DIR" pull --ff-only 2>/dev/null || warn "pull failed — using local copy"
  else
    info "cloning claude-config to $REPO_DIR"
    mkdir -p "$(dirname "$REPO_DIR")"
    git clone "$REPO_URL" "$REPO_DIR"
    ok "cloned to $REPO_DIR"
  fi
}

# ── generate .env.local ────────────────────────────────────────

generate_env() {
  header "generating .env.local"

  local env_file="$REPO_DIR/.env.local"
  local claude_home="${CLAUDE_HOME:-$HOME/.claude}"

  cat > "$env_file" <<EOF
# machine-specific config — generated by setup.sh on $(date -u +%Y-%m-%dT%H:%M:%SZ)
# this file is gitignored and NOT committed to the repo
# edit these values for your local environment

# platform: $OS_DISPLAY
PLATFORM=$PLATFORM
SHELL_NAME=$CURRENT_SHELL

# where claude code stores its config
CLAUDE_HOME=$claude_home

# where this repo lives
CLAUDE_CONFIG_REPO=$REPO_DIR

# obsidian vault path (used by wiki skill)
WIKI_VAULT_PATH=${WIKI_VAULT_PATH:-}

# project defaults — uncomment and edit as needed
# DEFAULT_DESIGN_SYSTEM=stripe
# TRELLO_BOARD_ID=
# JIRA_DOMAIN=
# JIRA_AGENT_EMAIL=
EOF

  ok "wrote $env_file"
}

# ── run first sync ──────────────────────────────────────────────

run_first_sync() {
  header "running first sync"

  local sync_script="$REPO_DIR/scripts/sync.sh"
  if [ ! -f "$sync_script" ]; then
    err "sync.sh not found at $sync_script"
    return 1
  fi

  # export env vars so sync picks them up
  export CLAUDE_CONFIG_REPO="$REPO_DIR"
  export CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"

  bash "$sync_script" push
}

# ── add env loader to shell rc ──────────────────────────────────

setup_shell_env() {
  header "shell environment"

  local env_file="$REPO_DIR/.env.local"
  local loader_comment="# claude-config env loader"
  local loader_line="[ -f \"$env_file\" ] && set -a && . \"$env_file\" && set +a"

  if [ "$CURRENT_SHELL" = "fish" ]; then
    # fish uses different syntax
    loader_line="if test -f \"$env_file\"; bass source \"$env_file\"; end"
  fi

  if [ -f "$SHELL_RC" ] && grep -qF "$loader_comment" "$SHELL_RC" 2>/dev/null; then
    ok "shell already loads .env.local"
    return
  fi

  prompt "add env loader to $SHELL_RC? [Y/n]"
  read -r confirm
  if [[ "$confirm" =~ ^[Nn] ]]; then
    warn "skipped — add this to your shell rc manually:"
    printf "  %s\n" "$loader_line"
    return
  fi

  printf "\n%s\n%s\n" "$loader_comment" "$loader_line" >> "$SHELL_RC"
  ok "added env loader to $SHELL_RC"
  info "run: source $SHELL_RC  (or open a new terminal)"
}

# ── print summary ───────────────────────────────────────────────

print_summary() {
  header "setup complete"

  printf "\n"
  printf "  ${BOLD}platform${NC}     %s\n" "$OS_DISPLAY"
  printf "  ${BOLD}shell${NC}        %s\n" "$CURRENT_SHELL"
  printf "  ${BOLD}repo${NC}         %s\n" "$REPO_DIR"
  printf "  ${BOLD}claude home${NC}  %s\n" "${CLAUDE_HOME:-$HOME/.claude}"
  if [ -n "${WIKI_VAULT_PATH:-}" ]; then
    printf "  ${BOLD}wiki vault${NC}  %s\n" "$WIKI_VAULT_PATH"
  fi
  printf "\n"

  info "config synced to ${CLAUDE_HOME:-$HOME/.claude}"
  info "env file at $REPO_DIR/.env.local"
  printf "\n"

  echo "next steps:"
  echo "  1. open a new terminal (or source $SHELL_RC)"
  echo "  2. run 'claude' in any project"
  echo "  3. try '/wiki ingest' to start your knowledge base"
  echo "  4. try '/gac' after making changes for smart commits"
  printf "\n"
  echo "day to day:"
  echo "  bash $REPO_DIR/scripts/sync.sh status         what differs"
  echo "  bash $REPO_DIR/scripts/sync.sh push --git     pull latest, apply it"
  echo "  bash $REPO_DIR/scripts/sync.sh pull           capture local edits"
  printf "\n"
  echo "machine-only settings go in ${CLAUDE_HOME:-$HOME/.claude}/settings.local.json"
  echo "sync never overwrites it, and it always wins over the repo's base."
}

# ── main ────────────────────────────────────────────────────────

main() {
  printf "\n${BOLD}${CYAN}claude-config setup${NC}\n"
  printf "═══════════════════\n\n"

  detect_platform
  detect_shell
  ok "detected: $OS_DISPLAY ($CURRENT_SHELL)"

  check_prerequisites
  ensure_repo
  find_obsidian_vault
  generate_env
  run_first_sync
  setup_shell_env
  print_summary
}

main "$@"
