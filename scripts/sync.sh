#!/usr/bin/env bash
set -euo pipefail

# sync claude-config repo to local claude code installation
# idempotent — safe to run multiple times, on any machine

REPO_URL="https://github.com/codywilliamson/claude-config.git"
REPO_DIR="${CLAUDE_CONFIG_REPO:-$HOME/dev/claude-config}"
TARGET_DIR="${CLAUDE_HOME:-$HOME/.claude}"

# --- helpers ---
info()  { printf "\033[0;34m→\033[0m %s\n" "$1"; }
ok()    { printf "\033[0;32m✓\033[0m %s\n" "$1"; }
warn()  { printf "\033[0;33m!\033[0m %s\n" "$1"; }
err()   { printf "\033[0;31m✗\033[0m %s\n" "$1" >&2; }

# --- step 1: ensure repo exists locally ---
if [ -d "$REPO_DIR/.git" ]; then
  info "pulling latest from claude-config repo"
  git -C "$REPO_DIR" pull --ff-only origin main 2>/dev/null \
    || git -C "$REPO_DIR" pull --ff-only origin master 2>/dev/null \
    || warn "pull failed — using local copy as-is"
else
  info "cloning claude-config repo to $REPO_DIR"
  mkdir -p "$(dirname "$REPO_DIR")"
  git clone "$REPO_URL" "$REPO_DIR"
fi

# --- step 2: ensure target dir exists ---
mkdir -p "$TARGET_DIR"

# --- step 3: sync tracked config files ---
# these are the only dirs/files we care about from the repo
SYNC_ITEMS=(CLAUDE.md settings.json keybindings.json statusline-command.sh agents commands hooks skills)

for item in "${SYNC_ITEMS[@]}"; do
  src="$REPO_DIR/$item"
  dst="$TARGET_DIR/$item"

  if [ ! -e "$src" ]; then
    warn "skipping $item (not in repo)"
    continue
  fi

  if [ -d "$src" ]; then
    mkdir -p "$dst"
    rsync -a --delete "$src/" "$dst/"
  else
    cp -f "$src" "$dst"
  fi
done

ok "synced config files"

# --- step 4: verify settings.json paths ---
# settings.json uses $HOME which bash resolves at runtime — no replacement needed
# clean up any legacy __CLAUDE_HOME__ placeholders if present
if [ -f "$TARGET_DIR/settings.json" ] && grep -q '__CLAUDE_HOME__' "$TARGET_DIR/settings.json" 2>/dev/null; then
  sed -i "s|\\\$HOME/\\.claude|$TARGET_DIR|g; s|__CLAUDE_HOME__|$TARGET_DIR|g" "$TARGET_DIR/settings.json"
  ok "migrated legacy path placeholders in settings.json"
fi

# --- step 5: ensure .gitignore exists in target ---
if [ ! -f "$TARGET_DIR/.gitignore" ] && [ -f "$REPO_DIR/.gitignore" ]; then
  cp "$REPO_DIR/.gitignore" "$TARGET_DIR/.gitignore"
  ok "copied .gitignore"
fi

# --- step 6: install plugins ---
if command -v claude &>/dev/null; then
  PLUGINS=(
    "anthropics/claude-plugins-official:frontend-design"
    "anthropics/claude-plugins-official:typescript-lsp"
    "anthropics/claude-plugins-official:claude-md-management"
    "anthropics/claude-plugins-official:superpowers"
    "anthropics/claude-plugins-official:github"
    "anthropics/claude-plugins-official:ralph-loop"
    "anthropics/claude-plugins-official:code-simplifier"
    "anthropics/claude-plugins-official:playwright"
    "anthropics/claude-plugins-official:agent-sdk-dev"
    "anthropics/claude-code:security-guidance"
    "anthropics/claude-code:feature-dev"
  )

  info "installing plugins (skips already-installed)"
  for plugin in "${PLUGINS[@]}"; do
    repo="${plugin%%:*}"
    name="${plugin##*:}"
    claude plugin install "$repo" "$name" 2>/dev/null && ok "installed $name" \
      || ok "$name already installed"
  done
else
  warn "claude cli not found — skipping plugin install"
  warn "install claude code first, then re-run this script"
fi

# --- step 7: make hooks executable ---
if [ -d "$TARGET_DIR/hooks" ]; then
  chmod +x "$TARGET_DIR/hooks/"*.sh 2>/dev/null || true
  ok "hooks marked executable"
fi

echo ""
ok "claude config synced to $TARGET_DIR"
